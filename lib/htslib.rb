# frozen_string_literal: true

require 'ffi'

require 'hts/version'

module HTS
  class Error < StandardError; end

  class << self
    attr_accessor :ffi_lib
  end

  suffix = ::FFI::Platform::LIBSUFFIX

  self.ffi_lib = if ENV['HTSLIBDIR']
                   File.expand_path("libhts.#{suffix}", ENV['HTSLIBDIR'])
                 else
                   File.expand_path("../vendor/libhts.#{suffix}", __dir__)
                 end
  autoload :FFI, 'hts/ffi'
end

# alias
HTSlib = HTS
