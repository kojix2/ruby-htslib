# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative "bam/header"
require_relative "bam/cigar"
require_relative "bam/flag"
require_relative "bam/record"
require_relative "utils/open_method"

module HTS
  class Bam
    include Enumerable
    extend Utils::OpenMethod

    attr_reader :file_path, :mode, :header
    # HtfFile is FFI::BitStruct
    attr_reader :htf_file

    def initialize(file_path, mode = "r", create_index: nil)
      file_path = File.expand_path(file_path)

      unless File.exist?(file_path)
        message = "No such SAM/BAM file - #{file_path}"
        raise message
      end

      @file_path = file_path
      @mode      = mode
      @htf_file  = LibHTS.hts_open(@file_path, mode)
      @header    = Bam::Header.new(LibHTS.sam_hdr_read(htf_file))
      # FIXME: should be defined here?
      @bam1      = LibHTS.bam_init1

      # read
      if mode[0] == "r"
        # load index
        @idx = LibHTS.sam_index_load(htf_file, file_path)
        # create index
        if create_index || (@idx.null? && create_index.nil?)
          warn "Create index for #{file_path}"
          LibHTS.sam_index_build(file_path, -1)
          @idx = LibHTS.sam_index_load(htf_file, file_path)
        end
      else
        # FIXME: implement
        raise "not implemented yet."
      end
    end

    def struct
      htf_file
    end

    def to_ptr
      htf_file.to_ptr
    end

    def write(alns)
      alns.each do
        LibHTS.sam_write1(htf_file, header, alns.b) > 0 || raise
      end
    end

    # Close the current file.
    def close
      LibHTS.hts_close(htf_file)
    end

    # Flush the current file.
    def flush
      # LibHTS.bgzf_flush(@htf_file.fp.bgzf)
    end

    def each(&block)
      # Each does not always start at the beginning of the file.
      # This is the common behavior of IO objects in Ruby.
      # This may change in the future.
      while LibHTS.sam_read1(htf_file, header, @bam1) > 0
        record = Record.new(@bam1, header)
        block.call(record)
      end
    end

    # query [WIP]
    def query(region)
      qiter = LibHTS.sam_itr_querys(@idx, header, region)
      begin
        slen = LibHTS.sam_itr_next(htf_file, qiter, @bam1)
        while slen > 0
          yield Record.new(@bam1, header)
          slen = LibHTS.sam_itr_next(htf_file, qiter, @bam1)
        end
      ensure
        LibHTS.hts_itr_destroy(qiter)
      end
    end
  end
end
