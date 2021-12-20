# frozen_string_literal: true

module HTS
  class Bcf
    class Record
      def initialize(bcf_t, bcf)
        @bcf1 = bcf_t
        @bcf = bcf
        @p1 = FFI::MemoryPointer.new(:pointer) # FIXME: naming
      end

      attr_reader :p1, :bcf

      def struct
        @bcf1
      end

      def to_ptr
        @bcf.to_ptr
      end

      # def inspect; end

      def formats; end

      def genotypes; end

      def pos
        @bcf1[:pos] + 1 # FIXME
      end

      def start
        @bcf1[:pos]
      end

      def stop
        @bcf1[:pos] + @bcf1[:rlen]
      end

      def id
        @bcf1[:d][:id]
      end

      def qual
        @bcf1[:qual]
      end

      def ref
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_STR)
        @bcf1[:d][:allele].get_pointer(0).read_string
      end

      def alt
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_STR)
        @bcf1[:d][:allele].get_array_of_pointer(
          FFI::TYPE_POINTER.size, @bcf1[:n_allele] - 1
        ).map { |c| c.read_string }
      end

      def alleles
        @bcf1[:d][:allele].get_array_of_pointer(
          0, @bcf1[:n_allele]
        ).map { |c| c.read_string }
      end

      def info
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_SHR)
        Info.new(self)
      end

      def format
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_FMT)
        Format.new(self)
      end
    end
  end
end
