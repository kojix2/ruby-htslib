# frozen_string_literal: true

module HTS
  class VCF
    class Variant
      def initialize(bcf_t, vcf)
        @c = bcf_t
        @vcf = vcf
      end

      # def inspect; end

      def formats; end

      def genotypes; end

      def pos
        @c[:pos] + 1
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
    end
  end
end
