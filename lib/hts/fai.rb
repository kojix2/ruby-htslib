# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Fai
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
      @path.delete_suffix!('.fai')
      FFI.fai_build(@path) if File.exist?(@path + '.fai')
      @fai = FFI.fai_load(@path)
      # at_exit{FFI.fai_destroy(@fai)}
    end

    # the number of sequences in the index.
    def size
      FFI.faidx_nseq(@fai)
    end
    alias length size

    # return the length of the requested chromosome.
    def chrom_size(chrom)
      raise ArgumentError, 'Expect chrom to be String or Symbol' unless chrom.is_a?(String) || chrom.is_a?(Symbol)

      chrom = chrom.to_s
      result = FFI.faidx_seq_len(@fai, chrom)
      result == -1 ? nil : result
    end
    alias chrom_length chrom_size

    # FIXME: naming and syntax
    def cget()
    end

    # FIXME: naming and syntax
    def get
    end

    # __iter__
  end
end
