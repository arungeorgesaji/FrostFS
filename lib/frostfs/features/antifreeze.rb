module FrostFS
  class Antifreeze
    ANTIFREEZE_EXTENSIONS = ['.log', '.tmp', '.cache', '.pid', '.lock']
    ANTIFREEZE_PATTERNS = [/temp/, /cache/, /log/, /\d{8}/] 
    
    def initialize(filesystem)
      @fs = filesystem
    end

    def has_antifreeze_properties?(file_path)
      return true if ANTIFREEZE_EXTENSIONS.include?(File.extname(file_path).downcase)
      return true if ANTIFREEZE_PATTERNS.any? { |pattern| pattern.match?(file_path) }
      
      check_file_content(file_path)
    end

    def antifreeze_strength(file_path)
      strength = 0
      
      strength += 30 if ANTIFREEZE_EXTENSIONS.include?(File.extname(file_path).downcase)
      
      strength += 20 if ANTIFREEZE_PATTERNS.any? { |pattern| pattern.match?(file_path) }
      
      strength += check_file_content(file_path) ? 50 : 0
      
      strength.clamp(0, 100)
    end

    def apply_antifreeze_effect(metadata, strength)
      effective_age = (Time.now.to_i - metadata.last_accessed) * (1 - strength / 200.0)
      effective_age.to_i
    end

    private

    def check_file_content(file_path)
      full_path = File.join(@fs.root_path, file_path)
      return false unless File.exist?(full_path)
      
      content = File.read(full_path, 1024)
      
      markers = ['TEMP', 'CACHE', 'LOG', 'SESSION', 'BUFFER']
      markers.any? { |marker| content.include?(marker) }
    rescue
      false
    end
  end
end
