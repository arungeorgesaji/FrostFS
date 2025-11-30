module FrostFS
  class TUI
    class BatchOperations
      def initialize(filesystem, app)
        @fs = filesystem
        @app = app
      end

      def show_batch_menu
        width = 50
        height = 12
        x = (Curses.cols - width) / 2
        y = (Curses.lines - height) / 2
        
        draw_border(x, y, width, height)
        
        lines = [
          "Batch Operations",
          "─" * (width - 4),
          "1. Thaw All Frozen Files",
          "2. Defragment High Fragmentation",
          "3. Send to Glacier Storage",
          "4. Find Old Files (>30 days)",
          "5. Export Statistics",
          "",
          "Press 1-5 or ESC"
        ]
        
        lines.each_with_index do |line, i|
          Curses.setpos(y + 2 + i, x + 2)
          Curses.addstr(line)
        end
        
        Curses.refresh
        
        case Curses.getch
        when '1' then thaw_all_frozen
        when '2' then defragment_high_frag
        when '3' then send_to_glacier_batch
        when '4' then find_old_files
        when '5' then export_statistics
        end
      end

      def thaw_all_frozen
        result = @fs.batch_thaw
        message = "Thawed: #{result[:thawed].size} files"
        message += " | Failed: #{result[:failed].size}" if result[:failed].any?
        @app.show_message(message)
      end

      def defragment_high_frag
        defragged = 0
        @fs.metadata_manager.all_files.each do |file_path|
          if @fs.should_defragment?(file_path)
            @fs.defragment_file(file_path)
            defragged += 1
          end
        end
        @app.show_message("Defragmented #{defragged} files")
      end

      def send_to_glacier_batch
        archived = 0
        @fs.metadata_manager.files_by_state(:deep_frozen).each do |file_path|
          result = @fs.send_to_glacier(file_path)
          archived += 1 if result[:success]
        end
        @app.show_message("Archived #{archived} files to glacier")
      end

      def find_old_files
        old_files = []
        cutoff = Time.now.to_i - (30 * 24 * 3600)
        
        @fs.metadata_manager.all_files.each do |file_path|
          metadata = @fs.metadata_manager.get(file_path)
          if metadata.last_accessed < cutoff
            old_files << file_path
          end
        end
        
        show_old_files_list(old_files)
      end

      def show_old_files_list(files)
        return @app.show_message("No old files found") if files.empty?
        
        width = 60
        height = [files.size + 6, 20].min
        x = (Curses.cols - width) / 2
        y = (Curses.lines - height) / 2
        
        draw_border(x, y, width, height)
        
        Curses.setpos(y + 1, x + 2)
        Curses.addstr("Old Files (>30 days): #{files.size} found")
        Curses.setpos(y + 2, x + 2)
        Curses.addstr("─" * (width - 4))
        
        files.first(height - 6).each_with_index do |file, i|
          Curses.setpos(y + 4 + i, x + 2)
          Curses.addstr("• #{file}")
        end
        
        if files.size > height - 6
          Curses.setpos(y + height - 2, x + 2)
          Curses.addstr("... and #{files.size - (height - 6)} more")
        end
        
        Curses.setpos(y + height - 1, x + 2)
        Curses.addstr("Press any key...")
        
        Curses.refresh
        Curses.getch
      end

      def export_statistics
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        csv_path = File.join(@fs.root_path, "frostfs_stats_#{timestamp}.csv")
        
        require 'csv'
        CSV.open(csv_path, 'w') do |csv|
          csv << ['File', 'State', 'Size', 'Fragmentation%', 'Access Count', 'Last Accessed']
          
          @fs.metadata_manager.all_files.each do |file_path|
            info = @fs.file_info(file_path)
            next if info[:error]
            
            csv << [
              file_path,
              info[:state],
              info[:size],
              @fs.fragmentation_level(file_path),
              info[:access_count],
              info[:last_accessed]
            ]
          end
        end
        
        @app.show_message("Exported stats to #{csv_path}")
      end

      def draw_border(x, y, width, height)
        Curses.setpos(y, x)
        Curses.addstr("┌" + "─" * (width - 2) + "┐")
        
        (1...height-1).each do |line|
          Curses.setpos(y + line, x)
          Curses.addstr("│" + " " * (width - 2) + "│")
        end
        
        Curses.setpos(y + height - 1, x)
        Curses.addstr("└" + "─" * (width - 2) + "┘")
      end
    end
  end
end
