module FrostFS
  class FrostPatterns
    PATTERNS = {
      active: "💧",      
      chilled: "❄️",    
      frozen: "🧊",      
      deep_frozen: "🏔️" 
    }

    def self.pattern_for_state(state)
      PATTERNS[state] || "�"
    end

    def self.visualize_file_tree(filesystem, path = ".")
      full_path = File.join(filesystem.root_path, path)
      return unless File.directory?(full_path)

      entries = Dir.entries(full_path).sort.reject { |e| e.start_with?('.') }
      
      entries.each do |entry|
        entry_path = File.join(path, entry)
        full_entry_path = File.join(filesystem.root_path, entry_path)
        
        if File.directory?(full_entry_path)
          puts "#{entry_path}/"
          visualize_file_tree(filesystem, entry_path)
        else
          state = filesystem.file_state(entry_path) rescue :unknown
          pattern = pattern_for_state(state)
          size = File.size(full_entry_path) rescue 0
          puts "  #{pattern} #{entry_path} (#{size} bytes)"
        end
      end
    end

    def self.generate_heat_map(filesystem)
      heat_data = {}
      
      filesystem.metadata_manager.all_files.each do |file_path|
        metadata = filesystem.metadata_manager.get(file_path)
        days_since_access = (Time.now.to_i - metadata.last_accessed) / (24 * 3600)
        
        heat_score = [100 - (days_since_access * 2), 0].max
        heat_data[file_path] = {
          score: heat_score,
          state: metadata.current_state,
          accesses: metadata.access_count
        }
      end
      
      heat_data
    end
  end
end
