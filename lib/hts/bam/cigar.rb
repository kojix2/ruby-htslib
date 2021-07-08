# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Bam
    class Cigar
      include Enumerable
      OPS = "MIDNSHP=XB"

      def initialize(cigar, n_cigar)
        @c = cigar
        @n_cigar = n_cigar
      end

      def to_s
        to_a.flatten.join
      end

      def each
        @n_cigar.times do |i|
          c = @c[i].read_uint32
          yield [FFI.bam_cigar_oplen(c),
                 FFI.bam_cigar_opchr(c)]
        end
      end
    end
  end
end
