require 'logger'

module FrostFS
  class FrostLogger
    def initialize(log_file = nil, level = Logger::INFO)
      @logger = Logger.new(log_file || STDOUT)
      @logger.level = level
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{severity}: #{msg}\n"
      end
    end

    def info(message)
      @logger.info(message)
    end

    def warn(message)
      @logger.warn(message)
    end

    def error(message)
      @logger.error(message)
    end

    def debug(message)
      @logger.debug(message)
    end

    def log_operation(operation, file_path, details = {})
      info("#{operation} #{file_path} #{details}")
    end
  end
end
