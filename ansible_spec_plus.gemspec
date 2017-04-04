# -*- encoding: utf-8 -*-
# lib = File.expand_path('../lib', __FILE__)
# $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
# require 'ansible_spec/version'

Gem::Specification.new do |gem|
  gem.name          = "ansible_spec_plus"
  gem.date          = Time.now.strftime("%Y-%m-%d")
  gem.version       = "1.0.0"
  gem.authors       = ["Meik Minks"]
  gem.email         = ["mminks@inoxio.de"]
  gem.description   = %q{Ansible Config Parser for Serverspec to test roles, hosts and playbooks. Providing test coverage.}
  gem.summary       = %q{Ansible Config Parser for Serverspec to test roles, hosts and playbooks. Providing test coverage.}
  gem.homepage      = "https://github.com/consort-it/ansible_spec_plus"
  gem.license       = "MIT"
  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.add_development_dependency "bundler", "~> 1.3"
  gem.add_development_dependency 'rake', '~> 0'
  gem.add_development_dependency 'diff-lcs', '~> 0'
  gem.add_development_dependency 'simplecov', '~> 0'

  gem.add_runtime_dependency 'ansible_spec', '~> 0.2', '>= 0.2.19'
end
