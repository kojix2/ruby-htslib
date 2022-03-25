# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Bam
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
          yield [LibHTS.bam_cigar_opchr(c),
                 LibHTS.bam_cigar_oplen(c)]
        end
      end
    end
  end
end
