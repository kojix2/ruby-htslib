# frozen_string_literal: true

require_relative "../htslib"

module HTS
  class Faidx
    attr_reader :file_name

    class << self
      alias open new
    end

    def initialize(file_name)
      @file_name = file_name
      @fai = LibHTS.fai_load(@file_name)

      # IO like API
      if block_given?
        begin
          yield self
        ensure
          close
        end
      end
    end

    def close
      LibHTS.fai_destroy(@fai)
    end

    # the number of sequences in the index.
    def size
      LibHTS.faidx_nseq(@fai)
    end
    alias length size

    # return the length of the requested chromosome.
    def chrom_size(chrom)
      unless chrom.is_a?(String) || chrom.is_a?(Symbol)
        # FIXME
        raise ArgumentError, "Expect chrom to be String or Symbol"
      end

      chrom = chrom.to_s
      result = LibHTS.faidx_seq_len(@fai, chrom)
      result == -1 ? nil : result
    end
    alias chrom_length chrom_size

    # FIXME: naming and syntax
    def cget; end

    # FIXME: naming and syntax
    def get; end

    # __iter__
  end
end
