# frozen_string_literal: true

require 'ffi'

require 'hts/version'

module HTS
  class Error < StandardError; end

  class << self
    attr_accessor :ffi_lib
  end

  htslib_sopath = File.expand_path("libhts.#{FFI::Platform::LIBSUFFIX}", "../htslib")
  self.ffi_lib = if File.exist?(htslib_sopath)
                   htslib_sopath
                 else
                   File.expand_path("libhts.#{FFI::Platform::LIBSUFFIX}", ENV['HTSLIBDIR'])
                 end
  autoload :FFI, 'hts/ffi'
end

# alias
HTSlib = HTS
