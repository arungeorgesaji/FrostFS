module FrostFS
  class Validator
    class ValidationError < StandardError; end

    def self.validate_file_path!(path)
      raise ValidationError, "Path cannot be empty" if path.nil? || path.empty?
      raise ValidationError, "Path cannot be absolute" if Pathname.new(path).absolute?
      raise ValidationError, "Path contains invalid characters" if path.include?("\0")
    end

    def self.validate_config!(config)
      required_times = [:chill_time, :freeze_time, :deep_freeze_time]
      required_times.each do |time_key|
        unless config.respond_to?(time_key) && config.send(time_key).is_a?(Numeric)
          raise ValidationError, "Missing or invalid #{time_key}"
        end
      end

      unless config.access_delay.is_a?(Hash)
        raise ValidationError, "Access delay must be a Hash"
      end
    end
  end
end
