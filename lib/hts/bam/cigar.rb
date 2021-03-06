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
        to_a.flatten.join
      end

      def each
        @n_cigar.times do |i|
          c = @pointer[i].read_uint32
          yield [LibHTS.bam_cigar_oplen(c),
                 LibHTS.bam_cigar_opchr(c)]
        end
      end
    end
  end
end
