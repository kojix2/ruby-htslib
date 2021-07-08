# frozen_string_literal: true

module HTS
  class VCF
    class Record
      def initialize(bcf_t, vcf)
        @c = bcf_t
        LibHTS.bcf_unpack(@c, LibHTS::BCF_UN_ALL) # FIXME
        @vcf = vcf
      end

      # def inspect; end

      def formats; end

      def genotypes; end

      def pos
        @c[:pos] + 1 # FIXME
      end

      def start
        @c[:pos]
      end

      def stop
        @c[:pos] + @c[:rlen]
      end

      def id
        @c[:d][:id]
      end

      def qual
        @c[:qual]
      end

      def ref
        @c[:d][:allele].get_pointer(0).read_string
      end
    end
  end
end
