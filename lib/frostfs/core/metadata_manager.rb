require 'json'
require 'fileutils'

module FrostFS
  class MetadataManager
    attr_reader :metadata, :metadata_path

    def initialize(metadata_path)
      @metadata_path = metadata_path
      @metadata = {}
      @metadata_file = File.join(metadata_path, 'metadata.json')
      
      load_metadata
    end

    def get(file_path)
      @metadata[file_path] ||= FileMetadata.new(file_path)
    end

    def update(file_path, metadata_obj)
      @metadata[file_path] = metadata_obj
    end

    def exists?(file_path)
      @metadata.key?(file_path)
    end

    def remove(file_path)
      @metadata.delete(file_path)
    end

    def save
      data = {}
      @metadata.each do |file_path, metadata_obj|
        data[file_path] = metadata_obj.to_h
      end
      
      File.write(@metadata_file, JSON.pretty_generate(data))
    end

    def load_metadata
      return unless File.exist?(@metadata_file)
      
      data = JSON.parse(File.read(@metadata_file))
      data.each do |file_path, meta_data|
        @metadata[file_path] = FileMetadata.from_h(meta_data)
      end
    end

    def all_files
      @metadata.keys
    end

    def files_by_state(state)
      @metadata.select { |_, meta| meta.current_state == state }.keys
    end
  end
end
