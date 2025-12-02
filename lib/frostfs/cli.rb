require 'thor'
require 'json'

module FrostFS
  class CLI < Thor
    desc "init PATH", "Initialize a new FrostFS filesystem"
    method_option :config, type: :string, aliases: '-c', desc: 'Path to config file'
    def init(path)
      config = load_config(options[:config])
      fs = Filesystem.new(path, config)
      puts "FrostFS initialized at: #{fs.root_path}"
    rescue => e
      error_output("Failed to initialize: #{e.message}")
    end

    desc "write FILE CONTENT", "Write content to a file"
    method_option :fs, type: :string, aliases: '-f', required: true, desc: 'FrostFS root path'
    def write(file_path, content)
      fs = load_filesystem(options[:fs])
      result = fs.write_file(file_path, content)
      
      if result[:success]
        puts "Written to #{file_path} (state: #{result[:state]})"
      else
        error_output("Write failed: #{result[:error]}")
      end
    end

    desc "read FILE", "Read content from a file"
    method_option :fs, type: :string, aliases: '-f', required: true, desc: 'FrostFS root path'
    method_option :thaw, type: :boolean, aliases: '-t', desc: 'Auto-thaw if frozen'
    def read(file_path)
      fs = load_filesystem(options[:fs])
      
      result = options[:thaw] ? fs.read_file_with_thaw(file_path) : fs.read_file(file_path)
      
      if result[:success]
        puts "Content: #{result[:content]}"
        puts "State: #{result[:state]}"
        puts "Access delay: #{result[:access_delay]}s" if result[:access_delay]
        puts "Auto-thawed: yes" if result[:auto_thawed]
      else
        handle_read_error(result)
      end
    end

    desc "info FILE", "Get detailed information about a file"
    method_option :fs, type: :string, aliases: '-f', required: true, desc: 'FrostFS root path'
    def info(file_path)
      fs = load_filesystem(options[:fs])
      result = fs.file_info(file_path)
      
      if result[:error]
        error_output("File not found: #{file_path}")
      else
        display_file_info(result)
      end
    end

    desc "list [STATE]", "List files, optionally filtered by state"
    method_option :fs, type: :string, aliases: '-f', required: true, desc: 'FrostFS root path'
    method_option :details, type: :boolean, aliases: '-d', desc: 'Show detailed information'
    def list(state = nil)
      fs = load_filesystem(options[:fs])
      
      state = state.to_sym if state && state != "all"
      
      files = if state && state != "all"
                fs.metadata_manager.files_by_state(state)
              else
                fs.metadata_manager.all_files
              end
      
      if files.empty?
        puts "No files found#{state ? " in state: #{state}" : ""}"
      else
        files.each do |file_path|
          if options[:details]
            info = fs.file_info(file_path)
            puts "#{file_path} | #{info[:state]} | #{info[:size]} bytes | #{info[:access_count]} accesses"
          else
            state = fs.file_state(file_path)
            puts "#{file_path} (#{state})"
          end
        end
      end
    end

    desc "thaw FILE", "Thaw a deeply frozen file"
    method_option :fs, type: :string, aliases: '-f', required: true, desc: 'FrostFS root path'
    def thaw(file_path)
      fs = load_filesystem(options[:fs])
      result = fs.thaw_file(file_path)
      
      if result[:success]
        puts "Thawed #{file_path} (now: #{result[:state]})"
      else
        error_output("Thaw failed: #{result[:error]}")
      end
    end

    desc "freeze FILE", "Force a file into frozen state"
    method_option :fs, type: :string, aliases: '-f', required: true, desc: 'FrostFS root path'
    method_option :state, type: :string, aliases: '-s', default: 'frozen', 
                 desc: 'Target state (chilled|frozen|deep_frozen)'
    def freeze(file_path)
      fs = load_filesystem(options[:fs])
      target_state = options[:state].to_sym
      
      unless [:chilled, :frozen, :deep_frozen].include?(target_state)
        error_output("Invalid state. Use: chilled, frozen, or deep_frozen")
        return
      end
      
      result = fs.state_manager.force_state(file_path, target_state, 'cli_force')
      puts "Forced #{file_path} to #{target_state}"
    end

    desc "stats", "Show filesystem statistics"
    method_option :fs, type: :string, aliases: '-f', required: true, desc: 'FrostFS root path'
    def stats
      fs = load_filesystem(options[:fs])
      stats = fs.state_stats
      total_files = stats.values.sum
      
      puts "FrostFS Statistics:"
      puts "Total files: #{total_files}"
      puts "State distribution:"
      stats.each do |state, count|
        percentage = total_files > 0 ? (count.to_f / total_files * 100).round(2) : 0
        puts "  #{state}: #{count} (#{percentage}%)"
      end
      
      metadata = fs.metadata_manager.metadata
      total_accesses = metadata.values.sum { |m| m.access_count }
      total_thaws = metadata.values.sum { |m| m.thaw_count }
      puts "Total accesses: #{total_accesses}"
      puts "Total thaws: #{total_thaws}"
    end

    desc "cleanup", "Remove metadata for deleted files"
    method_option :fs, type: :string, aliases: '-f', required: true, desc: 'FrostFS root path'
    def cleanup
      fs = load_filesystem(options[:fs])
      metadata = fs.metadata_manager
      
      initial_count = metadata.all_files.size
      metadata.all_files.each do |file_path|
        full_path = File.join(fs.root_path, file_path)
        metadata.remove(file_path) unless File.exist?(full_path)
      end
      metadata.save
      
      final_count = metadata.all_files.size
      removed = initial_count - final_count
      
      puts "Cleanup complete. Removed #{removed} orphaned metadata entries."
    end

    desc "update-states", "Update states for all files"
    method_option :fs, type: :string, aliases: '-f', required: true, desc: 'FrostFS root path'
    def update_states
      fs = load_filesystem(options[:fs])
      transitions = fs.update_all_states
      
      changed = transitions.count { |_, t| t && t[:old_state] != t[:new_state] }
      puts "Updated states for #{transitions.size} files (#{changed} state changes)"
    end

    private

    def load_filesystem(path, config = {})
      puts "DEBUG: Loading filesystem with path=#{path.inspect}, config=#{config.inspect}"
      Filesystem.new(path, config)
    rescue => e
      puts "ERROR: #{e.message}"
      puts "BACKTRACE:"
      puts e.backtrace.first(10).join("\n")
      exit 1
    end

    def load_config(config_path)
      return {} unless config_path && File.exist?(config_path)
      
      config_data = YAML.load_file(config_path) if config_path.end_with?('.yml', '.yaml')
      config_data ||= JSON.parse(File.read(config_path)) if config_path.end_with?('.json')
      config_data || {}
    rescue => e
      error_output("Config load error: #{e.message}")
      {}
    end

    def handle_read_error(result)
      case result[:error]
      when :requires_thaw
        error_output("File is deeply frozen. Use: frostfs read --thaw #{result[:path]}")
      when :not_found
        error_output("File not found: #{result[:path]}")
      else
        error_output("Read failed: #{result[:error]}")
      end
    end

    def display_file_info(info)
      puts "File: #{info[:path]}"
      puts "State: #{info[:state]}"
      puts "Size: #{info[:size]} bytes"
      puts "Access delay: #{info[:access_delay]}s"
      puts "Created: #{info[:created_at]}"
      puts "Last accessed: #{info[:last_accessed]}"
      puts "Last modified: #{info[:last_modified]}"
      puts "Access count: #{info[:access_count]}"
      puts "Thaw count: #{info[:thaw_count]}"
    end

    def error_output(message)
      puts "#{message}"
    end
  end
end
