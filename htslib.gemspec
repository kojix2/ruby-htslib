# frozen_string_literal: true

require_relative "lib/hts/version"

Gem::Specification.new do |spec|
  spec.name          = "htslib"
  spec.version       = HTS::VERSION
  spec.authors       = ["kojix2"]
  spec.email         = ["2xijok@gmail.com"]

  spec.summary       = "HTSlib bindings for Ruby"
  spec.homepage      = "https://github.com/kojix2/ruby-htslib"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["*.{md,txt}", "{lib,ext}/**/*"].reject do |path|
    path.include?("/coverage/") || path.match?(/\.(?:o|so|bundle|dll)$/) ||
      File.basename(path) == "Makefile" || File.basename(path) == "mkmf.log"
  end
  spec.require_path  = "lib"
  spec.extensions    = ["ext/htslib_native/extconf.rb"]

  spec.metadata["msys2_mingw_dependencies"] = "htslib"
end
