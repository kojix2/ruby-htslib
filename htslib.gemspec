# frozen_string_literal: true

require_relative 'lib/htslib/version'

Gem::Specification.new do |spec|
  spec.name          = 'htslib'
  spec.version       = HTSlib::VERSION
  spec.authors       = ['kojix2']
  spec.email         = ['2xijok@gmail.com']

  spec.summary       = 'HTSlib bindings for Ruby'
  spec.homepage      = 'https://github.com/kojix2/ruby-htslib'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.4'

  spec.files         = Dir['*.{md,txt}', '{lib,vendor}/**/*']
  spec.require_path  = 'lib'
  spec.add_dependency 'ffi'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
end
