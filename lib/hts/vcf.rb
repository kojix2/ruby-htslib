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

      @c = FFI.bcf_init
    end

    # def inspect; end

    def each(&block)
      block.call(Variant.new(@c, self)) unless FFI.bcf_read(@htf, @header.h, @c) == -1
    end

    def seq(tid); end

    def n_samples
      FFI.bcf_hdr_nsamples(header.h)
    end
  end

  class Format
    def initialize; end
  end
end
