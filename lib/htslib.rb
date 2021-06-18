# frozen_string_literal: true

require 'ffi'

require 'hts/version'

module HTS
  class Error < StandardError; end

  class << self
    attr_accessor :ffi_lib

    def search_htslib(name = nil)
      name ||= "libhts.#{::FFI::Platform::LIBSUFFIX}"
      lib_path = if ENV['HTSLIBDIR']
                   File.expand_path(name, ENV['HTSLIBDIR'])
                 else
                   File.expand_path("../vendor/#{name}", __dir__)
                 end
      return lib_path if File.exist?(lib_path)

      begin
        require 'pkg-config'
        lib_dir = PKGConfig.variable('htslib', 'libdir')
        lib_path = File.expand_path(name, lib_dir)
      rescue PackageConfig::NotFoundError
        warn "htslib.pc was not found in the pkg-config search path."
      end
      return lib_path if File.exist?(lib_path)

      warn "htslib shared library '#{name}' not found."
    end
  end

  self.ffi_lib = search_htslib

  # You can change the path of the shared library with `HTS.ffi_lib=`
  # before calling the FFI module.
  autoload :FFI, 'hts/ffi'
end

# alias
HTSlib = HTS

require_relative 'hts/bam'
require_relative 'hts/fai'
require_relative 'hts/tbx'
require_relative 'hts/vcf'
