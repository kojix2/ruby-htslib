# frozen_string_literal: true

module HTS
  class VCF
    class Variant
      def initialize(bcf_t, vcf)
        @c = bcf_t
        @vcf = vcf
      end

      #def inspect; end

      def formats; end

      def genotypes; end

      def pos
        @c[:pos] + 1
      end
    end
  end
end
