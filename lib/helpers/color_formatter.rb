require_relative 'colorize'
require 'logger'

module Helpers
  # colorful log formatter, also logs thread object id instead of process id
  class ColorFormatter < Logger::Formatter

    SCHEMA = %w(nothing green yellow red purple cyan)

    def call(severity, time, progname, msg)
      level = ::Logger::Severity.const_get(severity)
      color = SCHEMA[level]
      text = Format % [severity[0..0], format_datetime(time), Thread.current.object_id, severity, progname,
        msg2str(msg)]
      color ? Colorize.colorize(color, text) : text
    end
  end
end