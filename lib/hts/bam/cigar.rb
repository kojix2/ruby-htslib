# frozen_string_literal: true

module HTS
  class Bam < Hts
    # CIGAR string
    class Cigar
      include Enumerable

      def initialize(record)
        # The record is used at initialization and is not retained after that.
        bam1 = record.struct
        n_cigar = bam1[:core][:n_cigar]
        @c = LibHTS.bam_get_cigar(bam1).read_array_of_uint32(n_cigar)
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
