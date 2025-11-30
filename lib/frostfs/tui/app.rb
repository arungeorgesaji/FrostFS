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
        @batch_ops = BatchOperations.new(filesystem, self)  
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
        selected = get_selected_file
        
        file_info = if selected && !selected[:directory]
          state = @fs.file_state(selected[:relative_path]) rescue :active
          frag = @fs.fragmentation_level(selected[:relative_path]) rescue 0
          " | #{selected[:name]} (#{state}, #{frag}%)"
        else
          ""
        end
        
        status = "F:Freeze T:Thaw D:Defrag B:Batch M:Maint H:Help Q:Quit#{file_info}"
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
        when 'b', 'B' then @batch_ops.show_batch_menu 
        when 'h', 'H' then show_help
        when 'v', 'V' then show_thermal_map
        end
      end

      def show_help
        width = 60
        height = 18
        x = (Curses.cols - width) / 2
        y = (Curses.lines - height) / 2
        
        draw_border(x, y, width, height)
        
        help_lines = [
          "FROST COMMANDER HELP",
          "─" * (width - 4),
          "Navigation:",
          "  ↑↓     - Move cursor",
          "  ←→     - Switch panes", 
          "  Tab    - Switch active pane",
          "  Enter  - Open directory/file",
          "",
          "Operations:",
          "  F      - Freeze file",
          "  T      - Thaw file", 
          "  D      - Defragment file",
          "  I      - File info",
          "  B      - Batch operations",
          "  V      - Thermal map view",
          "  M      - Seasonal maintenance",
          "  H      - This help",
          "  Q      - Quit"
        ]
        
        help_lines.each_with_index do |line, i|
          Curses.setpos(y + 2 + i, x + 2)
          Curses.addstr(line)
        end
        
        Curses.refresh
        Curses.getch
      end

      def show_thermal_map
        thermal_map = ThermalMap.new(@fs)
        thermal_map.show
      end

      def draw_status_bar
        status_y = Curses.lines - 2
        Curses.setpos(status_y, 0)
        Curses.addstr("=" * Curses.cols)
        
        Curses.setpos(status_y + 1, 0)
        stats = @fs.state_stats
        selected = get_selected_file
        
        file_info = if selected && !selected[:directory]
          state = @fs.file_state(selected[:relative_path]) rescue :active
          frag = @fs.fragmentation_level(selected[:relative_path]) rescue 0
          " | #{selected[:name]} (#{state}, #{frag}%)"
        else
          ""
        end
        
        status = "F:Freeze T:Thaw D:Defrag B:Batch M:Maint H:Help Q:Quit#{file_info}"
        Curses.addstr(status.ljust(Curses.cols))
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
        current_path = @active_pane == :left ? @left_pane_path : @right_pane_path
        entries = get_directory_entries(current_path)
        selected_index = @active_pane == :left ? @left_cursor : @right_cursor
        
        return if entries.empty?
        
        selected_entry = entries[selected_index]
        return unless selected_entry[:directory]
        
        new_path = selected_entry[:full_path]
        
        if @active_pane == :left
          @left_pane_path = new_path
          @left_cursor = 0
        else
          @right_pane_path = new_path
          @right_cursor = 0
        end
      end

      def freeze_selected
        selected_file = get_selected_file
        return unless selected_file && !selected_file[:directory]
        
        show_freeze_menu(selected_file)
      end

      def show_freeze_menu(file_entry)
        width = 40
        height = 8
        x = (Curses.cols - width) / 2
        y = (Curses.lines - height) / 2
        
        draw_border(x, y, width, height)
        
        lines = [
          "Freeze: #{File.basename(file_entry[:name])}",
          "─" * (width - 4),
          "1. Chill",
          "2. Freeze", 
          "3. Deep Freeze",
          "",
          "Press 1-3 or ESC"
        ]
        
        lines.each_with_index do |line, i|
          Curses.setpos(y + 2 + i, x + 2)
          Curses.addstr(line)
        end
        
        Curses.refresh
        
        case Curses.getch
        when '1'
          @fs.state_manager.force_state(file_entry[:relative_path], :chilled, 'tui')
          show_message("Chilled #{file_entry[:name]}")
        when '2'
          @fs.state_manager.force_state(file_entry[:relative_path], :frozen, 'tui')
          show_message("Frozen #{file_entry[:name]}")
        when '3'
          @fs.state_manager.force_state(file_entry[:relative_path], :deep_frozen, 'tui')
          show_message("Deep Frozen #{file_entry[:name]}")
        end
      end

      def thaw_selected
        selected_file = get_selected_file
        return unless selected_file && !selected_file[:directory]
        
        result = @fs.thaw_file(selected_file[:relative_path])
        if result[:success]
          show_message("Thawed #{selected_file[:name]}")
        else
          show_message("Cannot thaw: #{result[:error]}", :error)
        end
      end

      def defragment_selected
        selected_file = get_selected_file
        return unless selected_file && !selected_file[:directory]
        
        frag_before = @fs.fragmentation_level(selected_file[:relative_path])
        
        if @fs.should_defragment?(selected_file[:relative_path])
          result = @fs.defragment_file(selected_file[:relative_path])
          show_message("Defragmented: #{result[:before]}% → #{result[:after]}%")
        else
          show_message("No need to defragment (#{frag_before}% fragmentation)")
        end
      end

      def run_maintenance
        show_message("Running seasonal maintenance...")
        result = @fs.seasonal_maintenance
        
        message = [
          "#{result[:season].capitalize} Maintenance Complete:",
          "Thawed: #{result[:thawed]} files",
          "Defragmented: #{result[:defragmented]} files", 
          "Archived: #{result[:archived]} files"
        ].join(" | ")
        
        show_message(message)
      end

      def show_file_info
        selected_file = get_selected_file
        return unless selected_file
        
        if selected_file[:directory]
          show_directory_info(selected_file)
        else
          popup = FileInfoPopup.new(@fs, selected_file[:relative_path])
          popup.show
        end
      end

      def show_directory_info(dir_entry)
        width = 50
        height = 10
        x = (Curses.cols - width) / 2
        y = (Curses.lines - height) / 2
        
        stats = count_directory_stats(dir_entry[:full_path])
        
        draw_border(x, y, width, height)
        
        lines = [
          "#{dir_entry[:name]}/",
          "─" * (width - 4),
          "Total files: #{stats[:total]}",
          "Active: #{stats[:active]} #{FrostPatterns.pattern_for_state(:active)}",
          "Chilled: #{stats[:chilled]} #{FrostPatterns.pattern_for_state(:chilled)}",
          "Frozen: #{stats[:frozen]} #{FrostPatterns.pattern_for_state(:frozen)}",
          "Deep Frozen: #{stats[:deep_frozen]} #{FrostPatterns.pattern_for_state(:deep_frozen)}",
          "",
          "Press any key..."
        ]
        
        lines.each_with_index do |line, i|
          Curses.setpos(y + 2 + i, x + 2)
          Curses.addstr(line)
        end
        
        Curses.refresh
        Curses.getch
      end

      def count_directory_stats(dir_path)
        stats = { total: 0, active: 0, chilled: 0, frozen: 0, deep_frozen: 0 }
        
        return stats unless File.directory?(dir_path)
        
        Dir.glob(File.join(dir_path, "**/*")).each do |full_path|
          next if File.directory?(full_path)
          next if full_path.start_with?(@fs.metadata_path)
          
          relative_path = full_path[@fs.root_path.length + 1..-1]
          begin
            state = @fs.file_state(relative_path)
            stats[:total] += 1
            stats[state] += 1
          rescue
          end
        end
        
        stats
      end

      def get_selected_file
        current_path = @active_pane == :left ? @left_pane_path : @right_pane_path
        entries = get_directory_entries(current_path)
        selected_index = @active_pane == :left ? @left_cursor : @right_cursor
        
        entries[selected_index] if selected_index < entries.size
      end

      def show_message(message, type = :info)
        width = [message.length + 4, 40].max
        height = 5
        x = (Curses.cols - width) / 2
        y = (Curses.lines - height) / 2
        
        color = case type
                when :error then COLORS[:error]
                when :info then COLORS[:active]
                end
        
        draw_border(x, y, width, height)
        
        Curses.setpos(y + 2, x + 2)
        Curses.attron(Curses::color_pair(color))
        Curses.addstr(message)
        Curses.attroff(Curses::color_pair(color))
        
        Curses.setpos(y + 4, x + 2)
        Curses.addstr("Press any key...")
        
        Curses.refresh
        Curses.getch
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
