# frozen_string_literal: true

module HTS
  class Bam < Hts
    # CIGAR string
    class Cigar
      include Enumerable

      # a uint32_t array (with 32 bits for every CIGAR op: length<<4|operation)
      attr_accessor :array

      # Create a new Cigar object from a string.
      # @param [String] cigar_str
      # The CIGAR string is converted to a uint32_t array in htslib.
      def self.parse(str)
        c = FFI::MemoryPointer.new(:pointer)
        m = FFI::MemoryPointer.new(:size_t)
        LibHTS.sam_parse_cigar(str, FFI::Pointer::NULL, c, m)
        cigar_array = c.read_pointer.read_array_of_uint32(m.read(:size_t))
        obj = new
        obj.array = cigar_array
        obj
      end

      def initialize(record = nil)
        if record
          # The record is used at initialization and is not retained after that.
          bam1 = record.struct
          n_cigar = bam1[:core][:n_cigar]
          @array = LibHTS.bam_get_cigar(bam1).read_array_of_uint32(n_cigar)
        else
          @array = []
        end
      end

      def to_s
        map { |op, len| "#{len}#{op}" }.join
      end

      def each
        return to_enum(__method__) unless block_given?

        @array.each do |c|
          op =  LibHTS.bam_cigar_opchr(c)
          len = LibHTS.bam_cigar_oplen(c)
          yield [op, len]
        end
      end

      def qlen
        a = FFI::MemoryPointer.new(:uint32, @array.size)
        a.write_array_of_uint32(@array)
        LibHTS.bam_cigar2qlen(@array.size, a)
      end

      def rlen
        a = FFI::MemoryPointer.new(:uint32, @array.size)
        a.write_array_of_uint32(@array)
        LibHTS.bam_cigar2rlen(@array.size, a)
      end

      def ==(other)
        other.is_a?(Cigar) && (@array == other.array)
      end

      def eql?(other)
        other.is_a?(Cigar) && @array.eql?(other.array)
      end
    end
  end
end
