# frozen_string_literal: true

module HTS
  class Bam < Hts
    # CIGAR string
    class Cigar
      include Enumerable

      def self.parse(str)
        c = FFI::MemoryPointer.new(:pointer)
        m = FFI::MemoryPointer.new(:size_t)
        LibHTS.sam_parse_cigar(str, FFI::Pointer::NULL, c, m)
        a_cigar = c.read_pointer.read_array_of_uint32(m.read(:size_t))
        obj = new
        obj.instance_variable_set(:@c, a_cigar)
        obj
      end

      def initialize(record = nil)
        if record
          # The record is used at initialization and is not retained after that.
          bam1 = record.struct
          n_cigar = bam1[:core][:n_cigar]
          @c = LibHTS.bam_get_cigar(bam1).read_array_of_uint32(n_cigar)
        else
          @c = []
        end
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
