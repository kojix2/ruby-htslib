# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative "bcf/header"
require_relative "bcf/info"
require_relative "bcf/format"
require_relative "bcf/record"

module HTS
  class Bcf
    include Enumerable

    attr_reader :file_path, :mode, :header

    def self.open(...)
      file = new(...)
      return file unless block_given?

      begin
        yield file
      ensure
        file.close
      end
      file
    end

    def initialize(filename, mode = "r", threads: nil)
      raise "HTS::Bcf.new() dose not take block; Please use HTS::Bcf.open() instead" if block_given?

      @file_path = filename == "-" ? "-" : File.expand_path(filename)

      if mode[0] == "r" && !File.exist?(file_path)
        message = "No such VCF/BCF file - #{file_path}"
        raise message
      end

      @mode      = mode
      @hts_file  = LibHTS.hts_open(file_path, mode)

      if threads
        r = LibHTS.hts_set_threads(@hts_file, threads)
        raise "Failed to set number of threads: #{threads}" if r < 0
      end

      return if mode[0] == "w"

      @header = Bcf::Header.new(@hts_file)
    end

    def struct
      @hts_file
    end

    def to_ptr
      @hts_file.to_ptr
    end

    def write_header
      @header = header.dup
      LibHTS.hts_set_fai_filename(header, @file_path)
      LibHTS.bcf_hdr_write(@hts_file, header.struct)
    end

    def write(var)
      var_dup = var.dup = var.dup
      LibHTS.bcf_write(@hts_file, header, var_dup) > 0 || raise
    end

    # Close the current file.
    def close
      LibHTS.hts_close(@hts_file)
      @hts_file = nil
    end

    def closed?
      @hts_file.nil?
    end

    def each
      return to_enum(__method__) unless block_given?

      while LibHTS.bcf_read(@hts_file, header, bcf1 = LibHTS.bcf_init) != -1
        record = Record.new(bcf1, self)
        yield record
      end
      self
    end

    def sample_count
      LibHTS.bcf_hdr_nsamples(header.struct)
    end
  end
end
