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
    # HtfFile is FFI::BitStruct
    attr_reader :htf_file

    class << self
      alias open new
    end

    def initialize(file_path, mode = "r")
      file_path = File.expand_path(file_path)

      unless File.exist?(file_path)
        message = "No such VCF/BCF file - #{file_path}"
        raise message
      end

      @file_path = file_path
      @mode      = mode
      @htf_file  = LibHTS.hts_open(file_path, mode)
      @header    = Bcf::Header.new(LibHTS.bcf_hdr_read(htf_file))

      # IO like API
      if block_given?
        begin
          yield self
        ensure
          close
        end
      end
    end

    def struct
      htf_file
    end

    def to_ptr
      htf_file.to_ptr
    end

    # Close the current file.
    def close
      LibHTS.hts_close(htf_file)
    end

    def each
      return to_enum(__method__) unless block_given?

      while LibHTS.bcf_read(htf_file, header, bcf1 = LibHTS.bcf_init) != -1
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
