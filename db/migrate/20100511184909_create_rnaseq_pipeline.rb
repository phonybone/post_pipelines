class CreateRnaseqPipeline < ActiveRecord::Migration
  def self.up
    create_table :rnaseq_pipelines do |t|
      t.string :name
      t.string :email
      t.string :status

      t.integer :sample_mixture_id
      t.integer :flow_cell_lane_id
      t.integer :pipeline_result_id

      t.string :working_dir
      t.string :export_file

      t.string :align_params
      t.string :org
      t.string :ref_genome
      t.integer :max_mismatches

      t.integer :qsub_job_id

      t.timestamps
    end
  end

  def self.down
    drop_table :rnaseq_pipelines
  end
end
