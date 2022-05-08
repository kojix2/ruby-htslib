# frozen_string_literal: true

require_relative "ffi_ext/struct"
require_relative "ffi_ext/pointer"

module HTS
  # A Module for working with native C HTSlib structures and functions.
  module LibHTS
    extend FFI::Library

    begin
      ffi_lib HTS.lib_path
    rescue LoadError => e
      raise LoadError, "#{e}\nCould not find #{HTS.lib_path}"
    end

    # @!macro attach_function
    #   @!method $1(${2--2})
    #   @return [${-1}] the return value of $0
    def self.attach_function(*)
      super
    rescue FFI::NotFoundError => e
      warn e.message
    end
  end
end

require_relative "libhts/constants"

# This is alphabetical order.
require_relative "libhts/kfunc"
require_relative "libhts/bgzf"
require_relative "libhts/hfile"
require_relative "libhts/hts"
require_relative "libhts/sam"
require_relative "libhts/cram"
require_relative "libhts/vcf"
require_relative "libhts/tbx"
require_relative "libhts/faidx"
require_relative "libhts/thread_pool"
