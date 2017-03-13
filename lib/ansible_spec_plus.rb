require_relative '../lib/helpers/log'

class AnsibleSpecPlus

  include Helpers::Log

  def initialize(options)
    self.all if options[:all] == true
  end

  def all
    log.info "Hello World!"
  end

end
