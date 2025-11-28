module FrostFS
  class TUI
    class FileInfoPopup
      def initialize(filesystem, file_path)
        @fs = filesystem
        @file_path = file_path
      end

      def show
        Curses.clear
        draw_popup
        Curses.getch  
      end

      def draw_popup
        width = 60
        height = 15
        x = (Curses.cols - width) / 2
        y = (Curses.lines - height) / 2

        draw_border(x, y, width, height)

        info = @fs.file_info(@file_path)
        state = @fs.file_state(@file_path)
        frag = @fs.fragmentation_level(@file_path)
        antifreeze = @fs.antifreeze_strength(@file_path)

        lines = [
          "#{@file_path}",
          "─" * (width - 4),
          "State: #{state} #{FrostPatterns.pattern_for_state(state)}",
          "Size: #{info[:size]} bytes",
          "Fragmentation: #{frag}%",
          "Antifreeze: #{antifreeze}%",
          "Access Count: #{info[:access_count]}",
          "Thaw Count: #{info[:thaw_count]}",
          "Last Accessed: #{info[:last_accessed]}",
          "Last Modified: #{info[:last_modified]}",
          "",
          "Press any key to continue..."
        ]

        lines.each_with_index do |line, i|
          Curses.setpos(y + 2 + i, x + 2)
          Curses.addstr(line)
        end
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
