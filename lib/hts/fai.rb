# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Fai
    # FIXME: API
    def self.open(path)
      fai = new(path)
      if block_given?
        yield(fai)
        fai.close
      else
        fai
      end
    end

    def initialize(path)
      @path = File.expand_path(path)
      @path.delete_suffix!(".fai")
      LibHTS.fai_build(@path) unless File.exist?("#{@path}.fai")
      @fai = LibHTS.fai_load(@path)
      raise if @fai.null?

      # at_exit{LibHTS.fai_destroy(@fai)}
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
      raise ArgumentError, "Expect chrom to be String or Symbol" unless chrom.is_a?(String) || chrom.is_a?(Symbol)

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
