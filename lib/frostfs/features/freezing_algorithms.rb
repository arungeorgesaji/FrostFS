module FrostFS
  module FreezingAlgorithms
    class StandardFreezer
      def initialize(config)
        @config = config
      end

      def calculate_state(metadata)
        now = Time.now.to_i
        time_since_access = now - metadata.last_accessed

        if time_since_access >= @config.deep_freeze_time
          :deep_frozen
        elsif time_since_access >= @config.freeze_time
          :frozen
        elsif time_since_access >= @config.chill_time
          :chilled
        else
          :active
        end
      end
    end

    class IntelligentFreezer
      def initialize(config)
        @config = config
      end

      def calculate_state(metadata)
        now = Time.now.to_i
        time_since_access = now - metadata.last_accessed
        
        access_frequency = metadata.access_count.to_f / [1, (now - metadata.created_at) / (24 * 3600)].max
        
        adjusted_time = time_since_access * resistance_factor(access_frequency)
        
        if adjusted_time >= @config.deep_freeze_time
          :deep_frozen
        elsif adjusted_time >= @config.freeze_time
          :frozen
        elsif adjusted_time >= @config.chill_time
          :chilled
        else
          :active
        end
      end

      private

      def resistance_factor(access_frequency)
        [1.0 / (1 + Math.log(1 + access_frequency)), 0.1].max
      end
    end

    class PredictiveFreezer
      def initialize(config)
        @config = config
        @access_patterns = {}
      end

      def record_access_pattern(file_path, time_of_day, day_of_week)
        @access_patterns[file_path] ||= {}
        @access_patterns[file_path][:last_accessed] = Time.now
        @access_patterns[file_path][:time_pattern] ||= Array.new(24, 0)
        @access_patterns[file_path][:time_pattern][time_of_day] += 1
      end

      def calculate_state(metadata)
        if should_thaw_soon?(metadata.file_path)
          :chilled
        else
          StandardFreezer.new(@config).calculate_state(metadata)
        end
      end

      private

      def should_thaw_soon?(file_path)
        patterns = @access_patterns[file_path]
        return false unless patterns
        
        current_hour = Time.now.hour
        patterns[:time_pattern][current_hour] > patterns[:time_pattern].max * 0.5
      end
    end
  end
end
