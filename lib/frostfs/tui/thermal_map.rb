module FrostFS
  class TUI
    class ThermalMap
      def initialize(filesystem)
        @fs = filesystem
      end

      def show
        Curses.clear
        draw_thermal_map
        Curses.getch
      end

      def draw_thermal_map
        Curses.setpos(0, 0)
        Curses.addstr("FROSTFS THERMAL MAP")
        Curses.setpos(1, 0)
        Curses.addstr("=" * Curses.cols)

        heat_data = @fs.thermal_imaging
        sorted_files = heat_data.sort_by { |_, data| -data[:score] }

        y = 2
        sorted_files.first(20).each do |file_path, data|
          break if y >= Curses.lines - 2
          
          heat_bar = generate_heat_bar(data[:score])
          state_pattern = FrostPatterns.pattern_for_state(data[:state])
          
          Curses.setpos(y, 0)
          Curses.addstr("#{state_pattern} #{heat_bar} #{file_path}")
          y += 1
        end

        Curses.setpos(Curses.lines - 1, 0)
        Curses.addstr("Press any key to return...")
      end

      def generate_heat_bar(score)
        bar_length = 20
        filled = (score / 100.0 * bar_length).round
        "[" + "█" * filled + "░" * (bar_length - filled) + "] #{score}%"
      end
    end
  end
end
