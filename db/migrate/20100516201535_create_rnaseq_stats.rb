class CreateRnaseqStats < ActiveRecord::Migration
  def self.up
    create_table :rnaseq_stats do |t|
      t.integer :rnaseq_pipeline_id
      t.integer :total_reads
      t.integer :total_aligned
      t.integer :unique_aligned
      t.integer :multi_aligned
      t.integer :spliced_aligned
      t.integer :n_genes
      t.timestamps
    end
  end

  def self.down
    drop_table :rnaseq_stats
  end
end
