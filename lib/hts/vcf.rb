# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative 'vcf/header'
require_relative 'vcf/variant'

module HTS
  class VCF
    include Enumerable
    attr_reader :file_path, :mode, :header, :htf

    def initialize(file_path, mode = 'r')
      @file_path = File.expand_path(file_path)
      File.exist?(@file_path) || raise("No such VCF/BCF file - #{@file_path}")

      @mode = mode
      @htf = FFI.hts_open(@file_path, mode)

      @header = VCF::Header.new(FFI.bcf_hdr_read(@htf))
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
