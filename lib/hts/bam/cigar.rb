# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Bam
    class Cigar
      OPS = 'MIDNSHP=XB'

      def initialize(cigar, n_cigar)
        @c = cigar
        @n_cigar = n_cigar
      end

      def to_s
        warn 'WIP'
        Array.new(@_cigar) do |i|
          c = @c[i]
          [FFI.bam_cigar_oplen(c),
           FFI.bam_cigar_opchar(c)]
        end
      end

      def each
      end
      # def inspect; end
    end
  end
end
