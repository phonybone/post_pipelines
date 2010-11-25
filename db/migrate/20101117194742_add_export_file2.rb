class AddExportFile2 < ActiveRecord::Migration
  def self.up
    add_column :rnaseq_pipelines, :export_file2, :string
  end

  def self.down
    remove_column :rnaseq_pipelines, :export_file2, :string
  end
end
