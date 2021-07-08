# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative "vcf/header"
require_relative "vcf/record"
require_relative "utils/open_method"

module HTS
  class VCF
    include Enumerable
    extend Utils::OpenMethod

    attr_reader :file_path, :mode, :htf, :header

    def initialize(file_path, mode = "r")
      file_path = File.expand_path(file_path)
      raise("No such VCF/BCF file - #{file_path}") unless File.exist?(file_path)

      @file_path = file_path
      @mode      = mode
      @htf       = LibHTS.hts_open(file_path, mode)
      @header = VCF::Header.new(LibHTS.bcf_hdr_read(htf))

      # FIXME: should be defined here?
      @c = LibHTS.bcf_init
    end

    # def inspect; end

    def each(&block)
      while LibHTS.bcf_read(htf, header.h, @c) != -1
        record = Record.new(@c, self)
        block.call(record)
      end
    end

    def seq(tid); end

    def n_samples
      LibHTS.bcf_hdr_nsamples(header.h)
    end
  end
end
