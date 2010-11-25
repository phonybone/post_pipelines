class RnaseqPipelinesController < ApplicationController
  require 'numeric_helpers'
  before_filter :login_required
  # GET /rnaseq_pipelines
  # GET /rnaseq_pipelines.xml
  def index
    @rnaseq_pipelines = RnaseqPipeline.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @rnaseq_pipelines }
    end
  end

  # GET /rnaseq_pipelines/1
  # GET /rnaseq_pipelines/1.xml
  def show
    @rp = RnaseqPipeline.find(params[:id])
    stats=@rp.stats

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @rnaseq_pipeline }
    end

    flash[:notice]=''
  end

  # GET /rnaseq_pipelines/new
  # GET /rnaseq_pipelines/new.xml
  def new
    @rnaseq_pipeline = RnaseqPipeline.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @rnaseq_pipeline }
    end
  end

  # GET /rnaseq_pipelines/1/edit
  def edit
    @rnaseq_pipeline = RnaseqPipeline.find(params[:id])
  end

  # POST /rnaseq_pipelines
  # POST /rnaseq_pipelines.xml
  def create
    @rnaseq_pipeline = RnaseqPipeline.new(params[:rnaseq_pipeline])
    @rnaseq_pipeline.email=current_user.email
    respond_to do |format|
      if @rnaseq_pipeline.save
        flash[:notice] = 'RnaseqPipeline was successfully created.'
        format.html { redirect_to(@rnaseq_pipeline) }
        format.xml  { render :xml => @rnaseq_pipeline, :status => :created, :location => @rnaseq_pipeline }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @rnaseq_pipeline.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /rnaseq_pipelines/1
  # PUT /rnaseq_pipelines/1.xml
  def update
    @rnaseq_pipeline = RnaseqPipeline.find(params[:id])

    respond_to do |format|
      if @rnaseq_pipeline.update_attributes(params[:rnaseq_pipeline])
        flash[:notice] = 'RnaseqPipeline was successfully updated.'
        format.html { redirect_to(@rnaseq_pipeline) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @rnaseq_pipeline.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /rnaseq_pipelines/1
  # DELETE /rnaseq_pipelines/1.xml
  def destroy
    @rnaseq_pipeline = RnaseqPipeline.find(params[:id])
    @rnaseq_pipeline.destroy

    respond_to do |format|
      format.html { redirect_to(rnaseq_pipelines_url) }
      format.xml  { head :ok }
    end
  end

########################################################################

  def launch_prep
    # question: does this need any data other than params[:selected_sample_mixtures]?

    # get sample_mixture objects from params[:selected_sample_mixtures]
    @sample_mixtures=get_sample_mixtures(params)

    @disable_launch=false
    begin
      # verify compatibility of sample_mixtures
      @email=current_user.email
      @aligner_params=RnaseqPipeline.config[:bowtie_opts]
      @ref_genome_name=@sample_mixtures[0].rna_seq_ref_genome.name
      SampleMixture.rnaseq_compatible?(@sample_mixtures)

    rescue RuntimeError => e
      @disable_launch=true
      @why_disabled="Incompatible samples:<br /> #{e.message}"
    end

  end
  
  def launch
    # get sample_mixture objects from params[:selected_sample_mixtures]
    @sample_mixtures=get_sample_mixtures(params)
    raise "no sample_mixtures" unless @sample_mixtures.length>0

    # make sure rnaseq_config file is loaded:
    raise "RNA-Seq values not loaded to AppConfig!" if AppConfig.rnaseq_dir.nil?

    # verify compatibility of sample_mixtures
    @disable_launch=false
    begin
      SampleMixture.rnaseq_compatible?(@sample_mixtures)

      # create new rnaseq_pipeline objects for each sample_mixture: one per export.txt file (via pipeline_results via fcl) (ugh)
      # can throw exceptions?
      @pipelines=RnaseqPipeline.new_from_sample_mixtures(@sample_mixtures,params)

      # save all valid rnaseq_pipeline object
      @pipelines.each do |p| 
        p.save; 
      end

      # launch all valid rnaseq_pipeline objects, noting number launched in flash[:notice] or some such
      flash[:notice]=''
      msgs=Array.new
      n_launched=0
      @pipelines.each do |p| 
        begin
          p.launch
          n_launched+=1
        rescue RuntimeError => rt
          msgs << rt.message
        end
      end
      msgs << "#{n_launched} pipelines launched"
      flash[:notice]+=msgs.join('<br />')


    rescue RuntimeError => e
      @disable_launch=true
      @why_disabled="Incompatible samples:<br /> #{e.message}"
      flash[:notice]=e.message
    end

    @ref_genome_name=@sample_mixtures[0].rna_seq_ref_genome.name
    @email=current_user.email
    @aligner_params=RnaseqPipeline.config[:bowtie_opts]

    render :launch_prep
  end

  def help
  end

########################################################################

  private
    # copied from sample_mixtures_controller#bulk_handler
    def get_sample_mixtures(params)
      selected_sample_mixtures = params["selected_sample_mixtures"] # checkboxes (ie, hash), normally
      logger.info "gsm: ssm is #{selected_sample_mixtures.inspect}"
      if (selected_sample_mixtures.is_a? String)
        ssm_id=selected_sample_mixtures
        selected_sample_mixtures=Hash.new
        selected_sample_mixtures[ssm_id]=1
      end

      sample_mixtures = Array.new
      selected_sample_mixtures.keys.each do |sample_mixture_id|
        next unless selected_sample_mixtures[sample_mixture_id].to_i==1
        sm=SampleMixture.find(sample_mixture_id)
        sample_mixtures << sm if sm.is_a? SampleMixture
      end
      sample_mixtures
    end
      

end


