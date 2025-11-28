require 'curses'
require 'io/console'

module FrostFS
  class TUI
    class App
      COLORS = {
        active: 1,      
        chilled: 2,      
        frozen: 3,      
        deep_frozen: 4, 
        glacier: 5,     
        error: 6        
      }

      def initialize(filesystem)
        @fs = filesystem
        @left_pane_path = filesystem.root_path
        @right_pane_path = filesystem.root_path
        @left_cursor = 0
        @right_cursor = 0
        @active_pane = :left
        @running = true
      end

      def run
        Curses.init_screen
        Curses.start_color
        Curses.crmode
        Curses.noecho
        Curses.stdscr.keypad(true)

        setup_colors
        main_loop
      ensure
        Curses.close_screen
      end

      private

      def setup_colors
        Curses.init_pair(COLORS[:active], Curses::COLOR_BLUE, Curses::COLOR_BLACK)
        Curses.init_pair(COLORS[:chilled], Curses::COLOR_CYAN, Curses::COLOR_BLACK)
        Curses.init_pair(COLORS[:frozen], Curses::COLOR_WHITE, Curses::COLOR_BLACK)
        Curses.init_pair(COLORS[:deep_frozen], Curses::COLOR_MAGENTA, Curses::COLOR_BLACK)
        Curses.init_pair(COLORS[:glacier], Curses::COLOR_YELLOW, Curses::COLOR_BLACK)
        Curses.init_pair(COLORS[:error], Curses::COLOR_RED, Curses::COLOR_BLACK)
      end

      def main_loop
        while @running
          draw_interface
          handle_input
        end
      end

      def draw_interface
        Curses.clear
        draw_header
        draw_panes
        draw_status_bar
        Curses.refresh
      end

      def draw_header
        Curses.setpos(0, 0)
        Curses.addstr("FROST COMMANDER - #{@fs.root_path}")
        Curses.setpos(1, 0)
        Curses.addstr("=" * Curses.cols)
      end

      def draw_panes
        pane_width = (Curses.cols - 3) / 2  
        height = Curses.lines - 4  

        draw_pane(2, 0, pane_width, height, :left)
        draw_pane(2, pane_width + 1, pane_width, height, :right)
      end

      def draw_pane(y, x, width, height, side)
        current_path = side == :left ? @left_pane_path : @right_pane_path
        cursor = side == :left ? @left_cursor : @right_cursor
        
        Curses.setpos(y-1, x)
        Curses.addstr(" #{File.basename(current_path)} ".ljust(width, " "))
        
        entries = get_directory_entries(current_path)
        
        (0...height).each do |line|
          Curses.setpos(y + line, x)
          index = cursor + line
          
          if index < entries.size
            entry = entries[index]
            draw_entry(entry, line, cursor, side == @active_pane)
          else
            Curses.addstr(" " * width)
          end
        end
      end

      def draw_entry(entry, line, cursor, is_active_pane)
        is_selected = (line == cursor)
        color = entry_color(entry)
        
        if is_selected && is_active_pane
          Curses.attron(Curses::A_REVERSE)
        end
        
        Curses.attron(Curses::color_pair(color))
        
        display_name = format_entry_display(entry)
        Curses.addstr(display_name)
        
        Curses.attroff(Curses::color_pair(color))
        Curses.attroff(Curses::A_REVERSE) if is_selected && is_active_pane
      end

      def entry_color(entry)
        return COLORS[:active] if entry[:directory]
        
        state = @fs.file_state(entry[:relative_path]) rescue :active
        case state
        when :active then COLORS[:active]
        when :chilled then COLORS[:chilled]
        when :frozen then COLORS[:frozen]
        when :deep_frozen then COLORS[:deep_frozen]
        when :glacier then COLORS[:glacier]
        else COLORS[:active]
        end
      end

      def format_entry_display(entry)
        if entry[:directory]
          "#{entry[:name]}/"
        else
          state = @fs.file_state(entry[:relative_path]) rescue :active
          pattern = FrostPatterns.pattern_for_state(state)
          frag = @fs.fragmentation_level(entry[:relative_path]) rescue 0
          "#{pattern} #{entry[:name]} (#{frag}%)"
        end.ljust(40)[0..39]  
      end

      def get_directory_entries(path)
        entries = []
        
        if path != @fs.root_path
          entries << { name: "..", directory: true, relative_path: ".." }
        end
        
        Dir.entries(path).sort.each do |entry|
          next if entry.start_with?('.')
          full_path = File.join(path, entry)
          relative_path = full_path[@fs.root_path.length + 1..-1]
          
          entries << {
            name: entry,
            directory: File.directory?(full_path),
            full_path: full_path,
            relative_path: relative_path
          }
        end
        
        entries
      end

      def draw_status_bar
        status_y = Curses.lines - 2
        Curses.setpos(status_y, 0)
        Curses.addstr("=" * Curses.cols)
        
        Curses.setpos(status_y + 1, 0)
        stats = @fs.state_stats
        status = "F:Freeze T:Thaw D:Defrag M:Maintenance Q:Quit | Active:#{stats[:active]||0} Frozen:#{stats[:frozen]||0}"
        Curses.addstr(status.ljust(Curses.cols))
      end

      def handle_input
        case Curses.getch
        when 'q', 'Q' then @running = false
        when Curses::KEY_UP then move_cursor(-1)
        when Curses::KEY_DOWN then move_cursor(1)
        when Curses::KEY_LEFT then @active_pane = :left
        when Curses::KEY_RIGHT then @active_pane = :right
        when "\t" then switch_active_pane
        when "\n" then enter_directory
        when 'f', 'F' then freeze_selected
        when 't', 'T' then thaw_selected
        when 'd', 'D' then defragment_selected
        when 'm', 'M' then run_maintenance
        when 'i', 'I' then show_file_info
        end
      end

      def move_cursor(delta)
        if @active_pane == :left
          @left_cursor = (@left_cursor + delta) % current_entries_count
        else
          @right_cursor = (@right_cursor + delta) % current_entries_count
        end
      end

      def current_entries_count
        current_path = @active_pane == :left ? @left_pane_path : @right_pane_path
        get_directory_entries(current_path).size
      end

      def switch_active_pane
        @active_pane = @active_pane == :left ? :right : :left
      end

      def enter_directory
      end

      def freeze_selected
      end

      def thaw_selected
      end

      def defragment_selected
      end

      def run_maintenance
      end

      def show_file_info
      end
    end
  end
end
