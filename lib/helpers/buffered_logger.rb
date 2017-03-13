require 'logger'
require_relative 'ring_buffer'

module Helpers

  class BufferedLogger < Logger

    #
    # :call-seq:
    #   Logger.new(name, shift_age = 7, shift_size = 1048576)
    #   Logger.new(name, shift_age = 'weekly')
    #
    # === Args
    #
    # +logdev+::
    #   The log device.  This is a filename (String) or IO object (typically
    #   +STDOUT+, +STDERR+, or an open file).
    # +shift_age+::
    #   Number of old log files to keep, *or* frequency of rotation (+daily+,
    #   +weekly+ or +monthly+).
    # +shift_size+::
    #   Maximum logfile size (only applies when +shift_age+ is a number).
    #
    # === Description
    #
    # Create an instance.
    #
    def initialize(logdev, shift_age = 0, shift_size = 1048576)
      super
      if logdev == STDOUT
        @stdout = STDOUT
      end

      @last_messages = RingBuffer.new(200)
    end

    #
    # :call-seq:
    #   Logger#add(severity, message = nil, progname = nil) { ... }
    #
    # === Args
    #
    # +severity+::
    #   Severity.  Constants are defined in Logger namespace: +DEBUG+, +INFO+,
    #   +WARN+, +ERROR+, +FATAL+, or +UNKNOWN+.
    # +message+::
    #   The log message.  A String or Exception.
    # +progname+::
    #   Program name string.  Can be omitted.  Treated as a message if no
    #   +message+ and +block+ are given.
    # +block+::
    #   Can be omitted.  Called to get a message string if +message+ is nil.
    #
    # === Return
    #
    # When the given severity is not high enough (for this particular logger),
    # log no message, and return +true+. Even if the severity is not high enough
    # we save each message in a ring buffer.
    #
    # === Description
    #
    # Log a message if the given severity is high enough. This is the generic
    # logging method.  Users will be more inclined to use #debug, #info, #warn,
    # #error, and #fatal.
    #
    # <b>Message format</b>: +message+ can be any object, but it has to be
    # converted to a String in order to log it.  Generally, +inspect+ is used
    # if the given object is not a String.
    # A special case is an +Exception+ object, which will be printed in detail,
    # including message, class, and backtrace.  See #msg2str for the
    # implementation if required.
    #
    # === Bugs
    #
    # * Logfile is not locked.
    # * Append open does not need to lock file.
    # * If the OS supports multi I/O, records possibly may be mixed.
    #
    def add(severity, message = nil, progname = nil, &block)
      super
      severity ||= UNKNOWN
      progname ||= @progname
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = @progname
        end
      end
      @last_messages.push(format_message(format_severity(severity), Time.now, progname, message))
      @stdout.flush if @stdout
      true
    end

    #
    # === Return
    #
    # Get array of last log messages. Even log messages with low severity are included.
    # The number of returned messages is limited by the size of the underlying ring buffer.
    #
    # === Description
    #
    # After calling this method the underling ring buffer is empty.
    #
    def last_messages
      @last_messages.flush
    end
  end
end
