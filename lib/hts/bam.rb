# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative 'bam/header'
require_relative 'bam/cigar'
require_relative 'bam/alignment'

module HTS
  class Bam
    include Enumerable
    attr_reader :fname, :mode, :header, :htf

    def initialize(fname, mode = 'r', create_index: nil, header: nil, fasta: nil)
      @fname = File.expand_path(fname)
      File.exist?(@fname) || raise("No such SAM/BAM file - #{@fname}")

      @mode = mode
      @htf = FFI.hts_open(@fname, mode)

      if mode[0] == 'r'
        @idx = FFI.sam_index_load(@htf, @fname)
        if (@idx.null? && create_index.nil?) || create_index
          FFI.sam_index_build(fname, -1)
          @idx = FFI.sam_index_load(@htf, @fname)
          warn 'NO querying'
        end
        @header = Bam::Header.new(FFI.sam_hdr_read(@htf))
        @b = FFI.bam_init1

      else
        # FIXME
        raise 'not implemented yet.'

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
      block.call(Alignment.new(@b, @header.h)) while FFI.sam_read1(@htf, @header.h, @b) > 0
    end

    # def call
  end
end
