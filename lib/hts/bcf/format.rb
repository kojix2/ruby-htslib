# frozen_string_literal: true

# https://github.com/brentp/hts-nim/blob/master/src/hts/vcf.nim
# This is a port from Nim.
# TODO: Make it more like Ruby.

module HTS
  class Bcf
    class Format
      def initialize; end

      def delete; end

      def get; end

      def set; end

      # def fields # iterator
      # end

      def genotypes; end
    end
  end
end
