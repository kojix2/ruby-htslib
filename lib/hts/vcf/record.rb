# frozen_string_literal: true

module HTS
  class Bcf
    class Record
      def initialize(bcf_t, vcf)
        @bcf1 = bcf_t
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_ALL) # FIXME
        @vcf = vcf
      end

      # def inspect; end

      def formats; end

      def genotypes; end

      def pos
        @bcf1[:pos] + 1 # FIXME
      end

      def start
        @bcf1[:pos]
      end

      def stop
        @bcf1[:pos] + @bcf1[:rlen]
      end

      def id
        @bcf1[:d][:id]
      end

      def qual
        @bcf1[:qual]
      end

      def ref
        @bcf1[:d][:allele].get_pointer(0).read_string
      end
    end
  end
end
