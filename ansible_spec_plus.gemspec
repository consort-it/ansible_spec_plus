# -*- encoding: utf-8 -*-
# lib = File.expand_path('../lib', __FILE__)
# $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
# require 'ansible_spec/version'

Gem::Specification.new do |gem|
  gem.name          = "ansible_spec_plus"
  gem.date          = Time.now.strftime("%Y-%m-%d")
  # gem.version       = AnsibleSpecPlus::VERSION
  gem.version       = "0.0.3"
  gem.authors       = ["Meik Minks"]
  gem.email         = ["mminks@inoxio.de"]
  gem.description   = %q{Ansible Config Parser for Serverspec. Run test Multi Role and Multi Host by Ansible Configuration}
  gem.summary       = %q{Ansible Config Parser for Serverspec. Run test Multi Role and Multi Host by Ansible Configuration}
  gem.homepage      = "https://github.com/volanja/ansible_spec"
  gem.license       = "MIT"
  gem.files         = Dir['lib/*.rb']
  gem.executables   = ['asp']
  gem.require_paths = ["lib"]

  gem.add_development_dependency "bundler", "~> 1.3"
  gem.add_development_dependency 'rake', '~> 0'
  gem.add_development_dependency 'diff-lcs', '~> 0'
  gem.add_development_dependency 'simplecov', '~> 0'

  gem.add_runtime_dependency 'ansible_spec', '~> 0.2', '>= 0.2.19'
end
