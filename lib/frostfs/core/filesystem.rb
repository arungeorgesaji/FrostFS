require 'fileutils'
require_relative 'metadata_manager'
require_relative 'state_manager'
require_relative '../operations/file_operations'

module FrostFS
  class Filesystem
    attr_reader :root_path, :metadata_path, :config, :metadata_manager, 
                :state_manager, :file_ops

    def initialize(root_path, config = {})
      @root_path = File.expand_path(root_path)
      @metadata_path = File.join(@root_path, '.frostfs')
      @config = config.is_a?(FrostConfig) ? config : FrostConfig.new(config)
      
      setup_filesystem
      @metadata_manager = MetadataManager.new(@metadata_path)
      @state_manager = StateManager.new(@config, @metadata_manager)
      @file_ops = FileOperations.new(self, @state_manager, @metadata_manager)
    end

    def write_file(path, content)
      @file_ops.write(path, content)
    end

    def read_file(path)
      @file_ops.read(path)
    end

    def read_file_with_thaw(path)
      @file_ops.read_with_thaw(path)
    end

    def delete_file(path)
      @file_ops.delete(path)
    end

    def file_info(path)
      @file_ops.info(path)
    end

    def thaw_file(path)
      @file_ops.thaw(path)
    end

    def file_exists?(path)
      @file_ops.exists?(path)
    end

    def file_state(path)
      @state_manager.current_state(path)
    end

    def state_stats
      @state_manager.state_statistics
    end

    def update_all_states
      @state_manager.update_all_states
    end

    private

    def setup_filesystem
      FileUtils.mkdir_p(@root_path)
      FileUtils.mkdir_p(@metadata_path)
    end
  end
end
