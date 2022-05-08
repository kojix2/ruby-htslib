# frozen_string_literal: true

require_relative "../htslib"

module HTS
  class Faidx
    attr_reader :file_name

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

    def initialize(file_name)
      if block_given?
        message = "HTS::Faidx.new() dose not take block; Please use HTS::Faidx.open() instead"
        raise message
      end

      @file_name = file_name
      @fai = LibHTS.fai_load(@file_name)

      raise Errno::ENOENT, "Failed to open #{@file_name}" if @fai.null?
    end

    def struct
      @fai
    end

    def close
      LibHTS.fai_destroy(@fai)
    end

    # the number of sequences in the index.
    def length
      LibHTS.faidx_nseq(@fai)
    end
    alias size length

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
    # def cget; end

    # FIXME: naming and syntax
    # def get; end

    # __iter__
  end
end
