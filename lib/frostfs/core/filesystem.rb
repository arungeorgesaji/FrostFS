require 'fileutils'
require 'json'

module FrostFS
  class Filesystem
    attr_reader :root_path, :metadata_path, :config

    def initialize(root_path, config = {})
      @root_path = File.expand_path(root_path)
      @metadata_path = File.join(@root_path, '.frostfs')
      @config = config.is_a?(FrostConfig) ? config : FrostConfig.new(config)
      
      setup_filesystem
    end

    private

    def setup_filesystem
      FileUtils.mkdir_p(@root_path)
      
      FileUtils.mkdir_p(@metadata_path)
      
      load_metadata
    end

    def load_metadata
      @metadata = {}
      metadata_file = File.join(@metadata_path, 'metadata.json')
      
      if File.exist?(metadata_file)
        data = JSON.parse(File.read(metadata_file))
        data.each do |file_path, meta_data|
          @metadata[file_path] = FileMetadata.from_h(meta_data)
        end
      end
    end

    def save_metadata
      metadata_file = File.join(@metadata_path, 'metadata.json')
      data = {}
      
      @metadata.each do |file_path, metadata_obj|
        data[file_path] = metadata_obj.to_h
      end
      
      File.write(metadata_file, JSON.pretty_generate(data))
    end
  end
end
