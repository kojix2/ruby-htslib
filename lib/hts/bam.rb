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
    attr_reader :file_path, :mode, :header, :htf

    def initialize(file_path, mode = "r", create_index: nil)
      @file_path = File.expand_path(file_path)
      File.exist?(@file_path) || raise("No such SAM/BAM file - #{@file_path}")

      @mode = mode
      @htf = FFI.hts_open(@file_path, mode)

      if mode[0] == "r"
        @idx = FFI.sam_index_load(@htf, @file_path)
        if (@idx.null? && create_index.nil?) || create_index
          FFI.sam_index_build(file_path, -1)
          @idx = FFI.sam_index_load(@htf, @file_path)
          warn "NO querying"
        end
        @header = Bam::Header.new(FFI.sam_hdr_read(@htf))
        @b = FFI.bam_init1

      else
        # FIXME
        raise "not implemented yet."

      end
    end

    def self.header_from_fasta; end

    def write(alns)
      alns.each do
        FFI.sam_write1(@htf, @header, alns.b) > 0 || raise
      end
    end

    # Close the current file.
    def close
      FFI.hts_close(@htf)
    end

    # Flush the current file.
    def flush
      raise
      # FFI.bgzf_flush(@htf.fp.bgzf)
    end

    def each(&block)
      # Each does not always start at the beginning of the file.
      # This is the common behavior of IO objects in Ruby.
      # This may change in the future.
      block.call(Record.new(@b, @header.h)) while FFI.sam_read1(@htf, @header.h, @b) > 0
    end

    # query [WIP]
    def query(region)
      qiter = FFI.sam_itr_querys(@idx, @header.h, region)
      begin
        slen = FFI.sam_itr_next(@htf, qiter, @b)
        while slen > 0
          yield Record.new(@b, @header.h)
          slen = FFI.sam_itr_next(@htf, qiter, @b)
        end
      ensure
        FFI.hts_itr_destroy(qiter)
      end
    end
  end
end
