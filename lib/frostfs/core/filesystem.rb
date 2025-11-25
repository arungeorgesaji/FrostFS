require 'fileutils'
require_relative 'metadata_manager'

module FrostFS
  class Filesystem
    attr_reader :root_path, :metadata_path, :config, :metadata_manager

    def initialize(root_path, config = {})
      @root_path = File.expand_path(root_path)
      @metadata_path = File.join(@root_path, '.frostfs')
      @config = config.is_a?(FrostConfig) ? config : FrostConfig.new(config)
      
      setup_filesystem
      @metadata_manager = MetadataManager.new(@metadata_path)
    end

    private

    def setup_filesystem
      FileUtils.mkdir_p(@root_path)
      FileUtils.mkdir_p(@metadata_path)
    end
  end
end
