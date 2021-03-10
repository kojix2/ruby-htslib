# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative 'vcf/variant'

module HTS
  class VCF
    include Enumerable
    attr_reader :fname, :mode, :header, :htf

    def initialize(fname, mode = 'r')
      @fname = File.expand_path(fname)
      File.exist?(@fname) || raise("No such VCF/BCF file - #{@fname}")

      @mode = mode
      @htf = FFI.hts_open(@fname, mode)

      @header = FFI.bcf_hdr_read(@htf)
    end

    # def inspect; end

    def each; end

    def seq; end

    def n_samples; end
  end

  class Format
    def initialize; end
  end
end
