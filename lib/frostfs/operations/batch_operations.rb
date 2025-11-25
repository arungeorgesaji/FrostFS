module FrostFS
  class BatchOperations
    attr_reader :filesystem

    def initialize(filesystem)
      @filesystem = filesystem
    end

    def thaw_files(pattern = "**/*")
      thawed = []
      failed = []
      
      Dir.glob(File.join(@filesystem.root_path, pattern)).each do |full_path|
        next if File.directory?(full_path)
        next if full_path.start_with?(@filesystem.metadata_path)
        
        relative_path = full_path[@filesystem.root_path.length + 1..-1]
        
        if @filesystem.file_state(relative_path) == :deep_frozen
          result = @filesystem.thaw_file(relative_path)
          if result[:success]
            thawed << relative_path
          else
            failed << relative_path
          end
        end
      end
      
      { thawed: thawed, failed: failed }
    end

    def archive_frozen_files(archive_dir, states = [:frozen, :deep_frozen])
      archived = []
      failed = []
      
      states.each do |state|
        @filesystem.metadata_manager.files_by_state(state).each do |file_path|
          begin
            full_path = File.join(@filesystem.root_path, file_path)
            archive_path = File.join(archive_dir, file_path)
            
            FileUtils.mkdir_p(File.dirname(archive_path))
            FileUtils.mv(full_path, archive_path)
            
            metadata = @filesystem.metadata_manager.get(file_path)
            metadata.update_state(:deep_frozen, 'archived')
            
            archived << file_path
          rescue => e
            failed << { file: file_path, error: e.message }
          end
        end
      end
      
      @filesystem.metadata_manager.save
      { archived: archived, failed: failed }
    end

    def export_stats_csv(output_path)
      require 'csv'
      
      CSV.open(output_path, 'w') do |csv|
        csv << ['File', 'State', 'Size', 'Access Count', 'Thaw Count', 'Last Accessed', 'Last Modified']
        
        @filesystem.metadata_manager.all_files.each do |file_path|
          info = @filesystem.file_info(file_path)
          next if info[:error]
          
          csv << [
            file_path,
            info[:state],
            info[:size],
            info[:access_count],
            info[:thaw_count],
            info[:last_accessed],
            info[:last_modified]
          ]
        end
      end
      
      { exported: @filesystem.metadata_manager.all_files.size, path: output_path }
    end

    def find_old_files(days_old, state = nil)
      cutoff_time = Time.now.to_i - (days_old * 24 * 3600)
      old_files = []
      
      @filesystem.metadata_manager.all_files.each do |file_path|
        metadata = @filesystem.metadata_manager.get(file_path)
        
        if metadata.last_accessed < cutoff_time && (state.nil? || metadata.current_state == state)
          old_files << {
            path: file_path,
            state: metadata.current_state,
            last_accessed: Time.at(metadata.last_accessed),
            days_inactive: (Time.now.to_i - metadata.last_accessed) / (24 * 3600.0).round(1)
          }
        end
      end
      
      old_files.sort_by { |f| f[:last_accessed] }
    end
  end
end
