class RnaseqPipeline < ActiveRecord::Base
  has_one :rnaseq_stats
  belongs_to :sample_mixture
  belongs_to :flow_cell_lane
  belongs_to :pipeline_result

  attr_accessor :erccs, :dry_run, :export_filepath

  require 'yaml'

  # read the rnaseq_pipeline.conf file (hardcoded location, how to get around???)
  # returns a hash
  def self.config
    config_file=File.replace_ext(__FILE__,'conf')
    conf=YAML.load_file config_file

    keys=conf.keys
    keys.each do |k|
      conf[k.to_sym]=conf[k]
    end
    conf
  end

########################################################################

  # return an Array of RnaseqPipelines based on an array of SampleMixtures
  # Note: many SampleMixtures will generate more than one RnaseqPipeline object
  def self.new_from_sample_mixtures(sample_mixtures,params)
    new_pipelines=Array.new
    msgs=Array.new
    sample_mixtures.each do |sm|
      sm.flow_cell_lanes.each do |fcl|
        rp=self.new

        rp.user_params! params
        rp.sample_mixture_params! sm
        rp.flow_cell_lane_params! fcl
        rp.pipeline_result_params! 

        rp.status='Created'
        rp.name=rp.label
        rp.working_dir=rp.make_working_dir

        new_pipelines << rp
        begin
          rp.valid?
        rescue RuntimeError=>e
          msgs<<e.message
        end
      end
    end
    raise msgs.join("<br />") if msgs.length>0
#    logger.warn "new pipelines: msgs is #{msgs.join(', ')}"
#    logger.warn "got #{new_pipelines.length} pipelines"
    new_pipelines
  end

  #---------------------------------------------------------------------
  def user_params! (params)
    rnaseq_params=params['rnaseq_pipeline']
    self.align_params=rnaseq_params['align_params']+" -n #{rnaseq_params[:max_mismatches]}"
    self.max_mismatches=rnaseq_params[:max_mismatches]
    self.email=rnaseq_params[:email]
    self.erccs=rnaseq_params[:erccs]
    self.dry_run=rnaseq_params[:dry_run]
    self
  end

  def sample_mixture_params! (sample_mixture)
    self.sample_mixture_id=sample_mixture.id
    self.org=sample_mixture.samples[0].reference_genome.organism.name.downcase
    self.ref_genome=sample_mixture.rna_seq_ref_genome.name
    self
  end

  def label
    "sample_#{sample_mixture_id}_fcl_#{flow_cell_lane_id}_pr_#{pipeline_result_id}"
  end

  def flow_cell_lane_params! (fcl)
    self.flow_cell_lane_id=fcl.id
    self.sample_mixture_id=fcl.sample_mixture.id
    self.pipeline_result_id=fcl.pipeline_results[-1].id 
    self
  end

  def pipeline_result_params! 
    self.export_file=File.basename(pipeline_result.eland_output_file);
    self.export_filepath=pipeline_result.eland_output_file
  end

  def vaild?
    raise "#{export_file}: not readable"    unless FileTest.readable? export_file
    export_dir=File.basename export_file
    raise "#{export_dir}: not a directory" unless FileTest.directory? export_dir
    raise "#{export_dir}: not writable"    unless FileTest.writable? export_dir
    self
  end

########################################################################

  def make_working_dir
    wd=['post_pipeline',sample_mixture_id.to_s,flow_cell_lane_id.to_s,pipeline_result_id.to_s].join('_') # eg 'post_pipeline_412_585_235'
    ts=Time.now.strftime  "%d%b%y.%H%M%S" # eg 21Apr10.032723
    File.join(File.dirname(pipeline_result.eland_output_file),wd,ts)
  end    


  def stats_file
    "#{working_dir}/#{export_file}.stats"
  end
  def gene_file
    "#{working_dir}/rds/#{export_file}.final.rpkm"
  end

  def entry_file
    "#{working_dir}/#{label}.entry.sh"
  end
  def entry_file_output
    "#{working_dir}/#{label}.entry.out"
  end
  def qsub_file
    "#{working_dir}/#{label}.qsub.sh"
  end
  def launch_file
    "#{working_dir}/#{label}.launch.sh"
  end

########################################################################

  def parse_stats(stats_file,gene_file)
    if !(FileTest.readable? stats_file and FileTest.readable? gene_file)
      logger.warn "missing stats file: #{stats_file}" unless FileTest.readable? stats_file
      logger.warn "missing gene file: #{gene_file}" unless FileTest.readable? gene_file
      return
    end

    stats=File.open(stats_file).read
    record=RnaseqStats.new
    regs=[ [/(\d+) total reads/,:total_reads],
           [/(\d+) total aligned reads/, :total_aligned],
           [/multi: (\d+)/, :multi_aligned],
           [/unique: (\d+)/, :unique_aligned],
           [/spliced: (\d+)/, :spliced_aligned]
         ]

    regs.each do |pair|
      regex=pair[0]
      symbol=pair[1]
      res=stats.match(regex)
      match=res[1]
      record.send("#{symbol}=",match)
    end

    # count all found genes (including putative)
    n_genes=`wc -l #{gene_file}`.chomp
    n_genes=n_genes.match(/^\d+/)[0]
    record.send("n_genes=",n_genes)

    record[:rnaseq_pipeline_id]=self.id # necessary?
    record.save
    record
  end


  def stats
    # return record from database if it exists; parse from file
    # and store, then return it if it doesn't.
    stats_record=self.rnaseq_stats
    stats_record=parse_stats(stats_file,gene_file) if stats_record.nil?
    self.rnaseq_stats=stats_record
    stats_record
  end

########################################################################


  def launch
    # mkdir working_dir and working_dir/rds; chmod of each to 777; also make a link to export file:
    raise "#{export_filepath}: no such file or unreadable" unless FileTest.readable? export_filepath
    FileUtils.mkdir_p "#{working_dir}/rds" unless FileTest.directory? "#{working_dir}/rds"
    FileUtils.chmod 0777, "#{working_dir}"
    FileUtils.chmod 0777, "#{working_dir}/rds"
    FileUtils.ln_s "#{export_filepath}",working_dir unless FileTest.exists? "#{working_dir}/#{export_file}"

    # create/write each of entry, qsub, and launch files
    write_entry_script
    write_launch_script
    write_qsub_script(flow_cell_lane)

    # system "/bin/sh #{entry_file} > #{entry_output}" # launches qsub job
    cmd="/bin/sh #{entry_file} > #{entry_file}.out"
    success=system(cmd)
    raise "#{sample_mixture.name_on_tube}: failed to launch (#{cmd}, #{$?})" unless success

    # parse entry file to find qsub_job_id, save it
    # Your job 24697 ("bowtie-build-human-100") has been submitted
    contents=File.open("#{entry_file}.out").read
    mr=contents.match(/Your job (\d+) .* has been submitted/)
    unless mr.nil? or mr[1].nil?
      qsub_job_id=mr[1].to_i      # if no match -> mr[1]==nil && qsub_job_id == 0
      if qsub_job_id>0
        self.qsub_job_id
        self.save
      end
    end
    
  end

#-----------------------------------------------------------------------

  def write_entry_script
    launch_qsub=launch_file()

    template_file=File.join(AppConfig.script_dir,AppConfig.entry_template)
    template=File.read template_file
    script=eval template
    File.open(entry_file(),"w") do |f| f.puts script; end 
  end

#-----------------------------------------------------------------------

  def write_launch_script
    qsub=AppConfig.qsub
    qsub_file=qsub_file()
    
    template_file=File.join(AppConfig.script_dir,AppConfig.launch_template)
    template=File.read template_file
    script=eval template
    File.open(launch_file(),"w") do |f| f.puts script; end 
  end

#-----------------------------------------------------------------------

  # Write the script that will launch the pipeline (invoked by the entry script)
  # see also make_launch_rnaseq_pipeline.rb
  def write_qsub_script(flow_cell_lane)
    pp_id=id
    ruby=AppConfig.ruby
    rnaseq_pipeline=File.join(AppConfig.script_dir,AppConfig.rnaseq_pipeline)
    readlen=sample_mixture.real_read_length # fixme: data in table is busted for some samples
    script_dir=AppConfig.script_dir
    rnaseq_dir=AppConfig.rnaseq_dir
    bin_dir=AppConfig.bin_dir
    dry_run_flag= dry_run.to_i>0 ? '-dry_run':'' # dry_run comes from form, so values are [0|1]
    email=self.email

    perl=AppConfig.perl
    gather_stats=File.join(AppConfig.script_dir,AppConfig.gather_stats)

    # ref_genome is only needed for bowtie, but include always anyway
    ref_genome=sample_mixture.rna_seq_ref_genome.name
    bowtie_opts=AppConfig.bowtie_opts
    
    template_file=File.join(AppConfig.script_dir,AppConfig.qsub_template)
    template=File.read template_file
    script=eval template
    File.open(qsub_file(),"w") do |f| f.puts script; end 
  end

end
