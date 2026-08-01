# frozen_string_literal: true

module HTS
  class Bam < Hts
    class Cigar
      include Enumerable

      OP_CHARS = "MIDNSHP=XB"
      attr_accessor :array

      def self.parse(str)
        new.tap { |cigar| cigar.array = Native.cigar_parse(str.to_s) }
      end

      def initialize(record = nil)
        @array = record ? record.__send__(:native_handle).cigar_values : []
      end

      def to_s = map { |op, len| "#{len}#{op}" }.join

      def each
        return to_enum(__method__) unless block_given?

        @array.each { |encoded| yield OP_CHARS[encoded & 15], encoded >> 4 }
      end

      def qlen = Native.cigar_qlen(@array)
      def rlen = Native.cigar_rlen(@array)
      def ==(other) = other.is_a?(Cigar) && @array == other.array
      def eql?(other) = other.is_a?(Cigar) && @array.eql?(other.array)
    end
  end
end
