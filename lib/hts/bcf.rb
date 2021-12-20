# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative "bcf/header"
require_relative "bcf/record"
require_relative "bcf/info"
require_relative "bcf/format"
require_relative "utils/open_method"

module HTS
  class Bcf
    include Enumerable
    extend Utils::OpenMethod

    attr_reader :file_path, :mode, :header
    # HtfFile is FFI::BitStruct
    attr_reader :htf_file

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

      # FIXME: should be defined here?
      @bcf1      = LibHTS.bcf_init
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

    def each(&block)
      while LibHTS.bcf_read(htf_file, header, @bcf1) != -1
        record = Record.new(@bcf1, self)
        block.call(record)
      end
    end

    def n_samples
      LibHTS.bcf_hdr_nsamples(header.struct)
    end
  end
end
