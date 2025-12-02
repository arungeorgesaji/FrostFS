require 'fileutils'

module FrostFS
  class FileOperations
    attr_reader :filesystem, :state_manager, :metadata_manager

    def initialize(filesystem, state_manager, metadata_manager)
      @filesystem = filesystem
      @state_manager = state_manager
      @metadata_manager = metadata_manager
    end

    def write(file_path, content)
      full_path = full_file_path(file_path)
      
      FileUtils.mkdir_p(File.dirname(full_path))
      
      File.write(full_path, content)
      
      metadata = @metadata_manager.get(file_path)
      metadata.record_modification
      @metadata_manager.update(file_path, metadata)
      
      @state_manager.update_state(file_path, 'write_operation')
      
      { success: true, path: file_path, state: metadata.current_state }
    end

    def read(file_path)
      if @state_manager.requires_thaw?(file_path)
        return { error: :requires_thaw, path: file_path, state: :deep_frozen }
      end
      
      delay = @state_manager.access_delay(file_path)
      sleep(delay) if delay > 0
      
      full_path = full_file_path(file_path)
      
      unless File.exist?(full_path)
        return { error: :not_found, path: file_path }
      end
      
      content = File.read(full_path)
      
      metadata = @metadata_manager.get(file_path)
      metadata.record_access
      @metadata_manager.update(file_path, metadata)
      
      @state_manager.update_state(file_path, 'read_operation')
      
      { 
        success: true, 
        path: file_path, 
        content: content, 
        state: metadata.current_state,
        access_delay: delay 
      }
    end

    def read_with_thaw(file_path)
      result = read(file_path)
      
      if result[:error] == :requires_thaw
        if @state_manager.thaw_file(file_path)
          result = read(file_path)
          result[:auto_thawed] = true
        end
      end
      
      result
    end

    def delete(file_path)
      full_path = full_file_path(file_path)
      
      if @state_manager.current_state(file_path) == :deep_frozen
        return { error: :cannot_delete_frozen, path: file_path, state: :deep_frozen }
      end
      
      if File.exist?(full_path)
        File.delete(full_path)
        @metadata_manager.remove(file_path)
        { success: true, path: file_path }
      else
        { error: :not_found, path: file_path }
      end
    end

    def exists?(file_path)
      File.exist?(full_file_path(file_path))
    end

    def info(file_path)
      full_path = full_file_path(file_path)
      
      return { error: :not_found, path: file_path } unless File.exist?(full_path)
      
      metadata = @metadata_manager.get(file_path)
      file_stat = File.stat(full_path)
      
      {
        path: file_path,
        state: metadata.current_state || :unknown,
        size: file_stat.size,
        created_at: metadata.created_at ? Time.at(metadata.created_at) : Time.now,
        last_accessed: metadata.last_accessed ? Time.at(metadata.last_accessed) : Time.now,
        last_modified: metadata.last_modified ? Time.at(metadata.last_modified) : Time.now,
        access_count: metadata.access_count || 0,
        thaw_count: metadata.thaw_count || 0,
        access_delay: @state_manager.access_delay(file_path)
      }
    end

    def thaw(file_path)
      if @state_manager.thaw_file(file_path)
        { success: true, path: file_path, state: :active }
      else
        { error: :not_frozen, path: file_path }
      end
    end

    private

    def full_file_path(relative_path)
      File.join(@filesystem.root_path, relative_path)
    end
  end
end
