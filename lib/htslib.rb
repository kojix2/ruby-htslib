# frozen_string_literal: true

require 'ffi'

require 'hts/version'

module HTS
  class Error < StandardError; end

  class << self
    attr_accessor :ffi_lib
  end
  self.ffi_lib = File.expand_path("libhts.#{FFI::Platform::LIBSUFFIX}", ENV['HTSLIBDIR'])
  autoload :FFI, 'hts/ffi'
end

# alias
HTSlib = HTS
