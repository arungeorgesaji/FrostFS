module FrostFS
  class IceCrystals
    def initialize(filesystem)
      @fs = filesystem
    end

    def calculate_fragmentation(file_path)
      metadata = @fs.metadata_manager.get(file_path)
      state = metadata.current_state
      days_frozen = (Time.now.to_i - metadata.last_accessed) / (24 * 3600)
      
      base_fragmentation = case state
                          when :active then 0
                          when :chilled then 10
                          when :frozen then 25
                          when :deep_frozen then 50
                          else 0
                          end
      
      time_fragmentation = (days_frozen / 7) * 5
      
      (base_fragmentation + time_fragmentation).clamp(0, 95)
    end

    def fragmentation_penalty(file_path)
      frag = calculate_fragmentation(file_path)
      (frag / 100.0) ** 2 * 2.0  
    end

    def should_defragment?(file_path)
      calculate_fragmentation(file_path) > 70
    end

    def defragment_file(file_path)
      frag_before = calculate_fragmentation(file_path)
      
      full_path = File.join(@fs.root_path, file_path)
      if File.exist?(full_path)
        content = File.read(full_path)
        File.write(full_path, content)  
        
        metadata = @fs.metadata_manager.get(file_path)
        metadata.record_access
        @fs.metadata_manager.update(file_path, metadata)
        
        frag_after = calculate_fragmentation(file_path)
        { success: true, before: frag_before, after: frag_after }
      else
        { error: :file_not_found }
      end
    end
  end
end
