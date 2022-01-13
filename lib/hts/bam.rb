# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative "bam/header"
require_relative "bam/cigar"
require_relative "bam/flag"
require_relative "bam/record"

module HTS
  class Bam
    include Enumerable

    attr_reader :file_path, :mode, :header

    class << self
      alias open new
    end

    def initialize(file_path, mode = "r", create_index: nil)
      file_path = File.expand_path(file_path)

      unless File.exist?(file_path)
        message = "No such SAM/BAM file - #{file_path}"
        raise message
      end

      @file_path = file_path
      @mode      = mode
      @hts_file  = LibHTS.hts_open(file_path, mode)
      @header    = Bam::Header.new(LibHTS.sam_hdr_read(@hts_file))

      # read
      if mode[0] == "r"
        # load index
        @idx = LibHTS.sam_index_load(@hts_file, file_path)
        # create index
        if create_index || (@idx.null? && create_index.nil?)
          warn "Create index for #{file_path}"
          LibHTS.sam_index_build(file_path, -1)
          @idx = LibHTS.sam_index_load(@hts_file, file_path)
        end
      else
        # FIXME: implement
        raise "not implemented yet."
      end

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
      @hts_file
    end

    def to_ptr
      @hts_file.to_ptr
    end

    def write(alns)
      alns.each do
        LibHTS.sam_write1(@hts_file, header, alns.b) > 0 || raise
      end
    end

    # Close the current file.
    def close
      LibHTS.hts_close(@hts_file)
    end

    # Flush the current file.
    def flush
      # LibHTS.bgzf_flush(@@hts_file.fp.bgzf)
    end

    def each
      # Each does not always start at the beginning of the file.
      # This is the common behavior of IO objects in Ruby.
      # This may change in the future.
      return to_enum(__method__) unless block_given?

      while LibHTS.sam_read1(@hts_file, header, bam1 = LibHTS.bam_init1) > 0
        record = Record.new(bam1, header)
        yield record
      end
      self
    end

    # query [WIP]
    def query(region)
      qiter = LibHTS.sam_itr_querys(@idx, header, region)
      begin
        bam1 = LibHTS.bam_init1
        slen = LibHTS.sam_itr_next(@hts_file, qiter, bam1)
        while slen > 0
          yield Record.new(bam1, header)
          bam1 = LibHTS.bam_init1
          slen = LibHTS.sam_itr_next(@hts_file, qiter, bam1)
        end
      ensure
        LibHTS.hts_itr_destroy(qiter)
      end
    end
  end
end
