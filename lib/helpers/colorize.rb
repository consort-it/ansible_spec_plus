module Helpers
  module Colorize
    module Colors
      NOTHING      = '0;0'
      BLACK        = '0;30'
      DARK_RED     = '0;31'
      DARK_GREEN   = '0;32'
      BROWN        = '0;33'
      BLUE         = '0;34'
      PURPLE       = '0;35'
      CYAN         = '0;36'
      GRAY         = '0;37'
      LIGHT_GRAY   = '0;37'
      DARK_GRAY    = '1;30'
      RED          = '1;31'
      GREEN        = '1;32'
      YELLOW       = '1;33'
      LIGHT_BLUE   = '1;34'
      LIGHT_PURPLE = '1;35'
      LIGHT_CYAN   = '1;36'
      WHITE        = '1;37'
    end

    class << self
      def colorize(color, text)
        color = Colorize::Colors.const_get(color.to_s.upcase)
        color ? colorful_text(color, text) : text
      rescue
#        puts color
#        puts $?
        text
      end

      def method_missing(symbol, *args)
        color = Colorize::Colors.const_get(color.to_s.upcase)
        return colorful_text(color, *args) if color
        super
      rescue
        super
#        puts symbol
#        puts $?
#        args
      end

      private

      def colorful_text(color, text)
        "\e[#{color}m#{text}\e[0;0m"
      end
    end
  end
end