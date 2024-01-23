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

  # * If the shared library exists in the vendor directory,
  #   it will be included in the package.
  # * Official releases uploaded to the RubyGem server
  #   will not include the shared library.
  spec.files         = Dir["*.{md,txt}", "{lib}/**/*", "vendor/*.{so,dylib,dll}"]
  spec.require_path  = "lib"

  spec.add_dependency "ffi"
  spec.add_dependency "ffi-bitfield"
  spec.add_dependency "pkg-config"

  spec.metadata["msys2_mingw_dependencies"] = "htslib"
end
