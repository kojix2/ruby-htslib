# frozen_string_literal: true

require "ffi"

require "hts/version"

module HTS
  class Error < StandardError; end

  class << self
    attr_accessor :lib_path

    def search_htslib(name = nil)
      name ||= "libhts.#{FFI::Platform::LIBSUFFIX}"
      lib_path = if ENV["HTSLIBDIR"]
                   File.expand_path(name, ENV["HTSLIBDIR"])
                 else
                   File.expand_path("../vendor/#{name}", __dir__)
                 end
      return lib_path if File.exist?(lib_path)

      begin
        require "pkg-config"
        lib_dir = PKGConfig.variable("htslib", "libdir")
        lib_path = File.expand_path(name, lib_dir)
      rescue PackageConfig::NotFoundError
        warn "htslib.pc was not found in the pkg-config search path."
      end
      return lib_path if File.exist?(lib_path)

      warn "htslib shared library '#{name}' not found."
    end
  end

  self.lib_path = search_htslib

  # You can change the path of the shared library with `HTS.lib_path=`
  # before calling the LibHTS module.
  autoload :LibHTS, "hts/libhts"
  
  autoload :Bam,    "hts/bam"
  autoload :Bcf,    "hts/bcf"
  autoload :Tabix,  "hts/tabix"
  autoload :Faidx,  "hts/faidx"
end
