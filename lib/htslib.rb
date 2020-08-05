# frozen_string_literal: true

require 'ffi'

require 'htslib/version'

module HTSlib
  class Error < StandardError; end

  class << self
    attr_accessor :ffi_lib
  end
  self.ffi_lib = File.expand_path("libhts.#{FFI::Platform::LIBSUFFIX}", ENV['HTSLIBDIR'])
  autoload :Native, 'htslib/ffi'
end
