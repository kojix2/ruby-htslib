# frozen_string_literal: true

module HTS
  class Bcf
    class Record
      def initialize(bcf_t, bcf)
        @bcf1 = bcf_t
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_ALL) # FIXME
        @bcf = bcf
      end

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
        @bcf1[:d][:allele].get_pointer(0).read_string
      end

      def alt
        @bcf1[:d][:allele].get_array_of_pointer(FFI::TYPE_POINTER.size, @bcf1[:n_allele] - 1).map { |c| c.read_string }
      end

      def alleles
        @bcf1[:d][:allele].get_array_of_pointer(0, @bcf1[:n_allele]).map { |c| c.read_string }
      end
    end
  end
end
