class SamplesController < ApplicationController

  def pipeline
    @sample=Sample.find(params[:id])
    
    @email=current_user.email
    @disable_launch=false
    @why_disabled=''
    @aligner_params=RnaseqPipeline.config[:bowtie_opts]

    # Check for existing export_file (hey, it happens (see sample w/id=232)
    # fixme: Can't yet; at least not easily; have to check all fcl's

    # Check for valid prep kit:
    if @sample.sample_prep_kit.name!='mRNASeq'
      @disable_launch=true
      @why_disabled="Sample was not prepared with the mRNAseq prep kit (#{@sample.sample_prep_kit.name})"
    end

    # check for valid ref_genome
    if !@disable_launch
      begin
        @ref_genome_name=@sample.sample_mixture.rna_seq_ref_genome.description
      rescue RuntimeError => err
        @ref_genome_name=err.message
        @disable_launch=true
        @why_disabled="No valid reference genome found"
      end
    end
  end

end
