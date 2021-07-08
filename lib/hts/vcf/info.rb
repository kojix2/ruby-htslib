# frozen_string_literal: true

# https://github.com/brentp/hts-nim/blob/master/src/hts/vcf.nim
# This is a port from Nim.
# TODO: Make it more like Ruby.

module HTS
  class VCF
    class Info
      def initialize; end

      def has_flag?; end

      def get; end

      def set; end

      def delete; end

      # def fields # iterator
      # end
    end
  end
end
