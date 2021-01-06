# frozen_string_literal: true

module HTS
  module FFI
    extend ::FFI::Library

    begin
      ffi_lib HTS.ffi_lib
    rescue LoadError => e
      raise LoadError, "Could not find #{HTS.ffi_lib}"
    end

    def self.attach_function(*)
      super
    rescue ::FFI::NotFoundError => e
      warn e.message
    end
  end
end

require_relative 'ffi/struct'
require_relative 'ffi_constants'

# alphabetical order
require_relative 'ffi/bgzf'
require_relative 'ffi/faidx'
require_relative 'ffi/hfile'
require_relative 'ffi/hts'
require_relative 'ffi/sam'
require_relative 'ffi/kfunc'
require_relative 'ffi/tbx'
require_relative 'ffi/vcf'
