# frozen_string_literal: true

module HTS
  class Bam < Hts
    # CIGAR string
    class Cigar
      include Enumerable

      def initialize(pointer, n_cigar)
        @pointer = pointer
        @n_cigar = n_cigar
      end

      def to_ptr
        @pointer
      end

      def to_s
        map { |op, len| "#{len}#{op}" }.join
      end

      def each
        return to_enum(__method__) unless block_given?

        @n_cigar.times do |i|
          c = @pointer[i].read_uint32
          op =  LibHTS.bam_cigar_opchr(c)
          len = LibHTS.bam_cigar_oplen(c)
          yield [op, len]
        end
      end
    end
  end
end
