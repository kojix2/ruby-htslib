# frozen_string_literal: true

module HTS
  class Bam < Hts
    # CIGAR string
    class Cigar
      include Enumerable

      def initialize(pointer, n_cigar)
        @n_cigar = n_cigar
        # Read the pointer before the memory is changed.
        # Especially when called from a block of `each` iterator.
        @c = pointer.read_array_of_uint32(n_cigar)
      end

      def to_s
        map { |op, len| "#{len}#{op}" }.join
      end

      def each
        return to_enum(__method__) unless block_given?

        @c.each do |c|
          op =  LibHTS.bam_cigar_opchr(c)
          len = LibHTS.bam_cigar_oplen(c)
          yield [op, len]
        end
      end
    end
  end
end
