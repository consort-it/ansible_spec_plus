require 'logger'
require_relative 'color_formatter'
require_relative 'buffered_logger'

module Helpers
  module Log
    class << self
      def log
        unless @logger
          @logger = BufferedLogger.new($stdout)
          @logger.formatter = ColorFormatter.new if $stdout.tty?
        end
        @logger
      end

      def log=(logger)
        @logger = logger
        log.info('changed logger')
      end

      def debug?
        !@no_debug
      end

      def set_debug(debug, level = ::Logger::INFO)
        @no_debug = !debug
        log.level = level
      end

      def last_messages
        return [] unless @logger
        @logger.last_messages
      end
    end

    def self.included(base)
      class << base
        def log
          Log.log
        end

        def log=(logger)
          Log.log=(logger)
        end

        def debug?
          Log.debug?
        end

        def set_debug(debug, level = Logger::INFO)
          Log.set_debug(debug, level)
        end

        def last_messages
          Log.last_messages
        end
      end
    end

    def log
      Log.log
    end

    def log=(logger)
      Log.log=(logger)
    end

    def debug?
      Log.debug?
    end

    def set_debug(debug, level = ::Logger::INFO)
      Log.set_debug(debug, level)
    end

    def last_messages
      Log.last_messages
    end
  end
end
