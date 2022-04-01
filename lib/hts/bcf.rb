# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative "../htslib"

require_relative "hts"
require_relative "bcf/header"
require_relative "bcf/info"
require_relative "bcf/format"
require_relative "bcf/record"

module HTS
  class Bcf < Hts
    include Enumerable

    attr_reader :file_name, :index_path, :mode, :header

    def self.open(*args, **kw)
      file = new(*args, **kw) # do not yield
      return file unless block_given?

      begin
        yield file
      ensure
        file.close
      end
      file
    end

    def initialize(file_name, mode = "r", threads: nil, index: nil, create_index: false)
      if block_given?
        message = "HTS::Bcf.new() dose not take block; Please use HTS::Bcf.open() instead"
        raise message
      end

      @file_name = file_name

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      @mode      = mode
      @hts_file  = LibHTS.hts_open(@file_name, mode)

      if threads&.> 0
        r = LibHTS.hts_set_threads(@hts_file, threads)
        raise "Failed to set number of threads: #{threads}" if r < 0
      end

      return if mode[0] == "w"

      @header = Bcf::Header.new(@hts_file)
    end

    def write_header
      @header = header.dup
      LibHTS.hts_set_fai_filename(header, @file_name)
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

    def sample_count
      header.sample_count
    end

    def sample_names
      header.sample_names
    end

    def each
      return to_enum(__method__) unless block_given?

      while LibHTS.bcf_read(@hts_file, header, bcf1 = LibHTS.bcf_init) != -1
        record = Record.new(bcf1, header)
        yield record
      end
      self
    end
  end
end
