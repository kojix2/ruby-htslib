# frozen_string_literal: true

module HTS
  class Bcf < Hts
    # A class for working with VCF records.
    class Record
      def initialize(header, bcf_t = nil)
        @bcf1 = bcf_t || LibHTS.bcf_init
        @header = header
      end

      attr_reader :header

      def struct
        @bcf1
      end

      def to_ptr
        @bcf1.to_ptr
      end

      # Get the reference id of the record.
      def rid
        @bcf1[:rid]
      end

      def rid=(rid)
        @bcf1[:rid] = rid
      end

      # Get the chromosome of variant.
      def chrom
        LibHTS.bcf_hdr_id2name(@header.struct, rid)
      end

      # Return 0-based position.
      def pos
        @bcf1[:pos]
      end

      def pos=(pos)
        @bcf1[:pos] = pos
      end

      # Return the 0-based, exclusive end position
      def endpos
        pos + @bcf1[:rlen]
      end

      # Return the value of the ID column.
      def id
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_INFO)
        @bcf1[:d][:id]
      end

      def id=(id)
        LibHTS.bcf_update_id(@header, @bcf1, id)
      end

      def clear_id
        LibHTS.bcf_update_id(@header, @bcf1, ".")
      end

      def ref
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_STR)
        @bcf1[:d][:allele].get_pointer(0).read_string
      end

      def alt
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_STR)
        @bcf1[:d][:allele].get_array_of_pointer(
          FFI::TYPE_POINTER.size, @bcf1[:n_allele] - 1
        ).map(&:read_string)
      end

      def alleles
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_STR)
        @bcf1[:d][:allele].get_array_of_pointer(
          0, @bcf1[:n_allele]
        ).map(&:read_string)
      end

      # Get variant quality.
      def qual
        @bcf1[:qual]
      end

      def qual=(qual)
        @bcf1[:qual] = qual
      end

      def filter
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_FLT)
        d = @bcf1[:d]
        n_flt = d[:n_flt]

        case n_flt
        when 0
          "PASS"
        when 1
          id = d[:flt].read_int
          LibHTS.bcf_hdr_int2id(@header.struct, LibHTS::BCF_DT_ID, id)
        when 2..nil
          d[:flt].get_array_of_int(0, n_flt).map do |i|
            LibHTS.bcf_hdr_int2id(@header.struct, LibHTS::BCF_DT_ID, i)
          end
        else
          raise "Unexpected number of filters. n_flt: #{n_flt}"
        end
      end

      def info(key = nil)
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_SHR)
        info = Info.new(self)
        if key
          info.get(key)
        else
          info
        end
      end

      def format(key = nil)
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_FMT)
        if key
          Format.new(self).get(key)
        else
          Format.new(self)
        end
      end

      def to_s
        ksr = LibHTS::KString.new
        raise "Failed to format record" if LibHTS.vcf_format(@header.struct, @bcf1, ksr) == -1

        ksr[:s]
      end

      private

      def initialize_copy(orig)
        @header = orig.header
        @bcf1 = LibHTS.bcf_dup(orig.struct)
      end
    end
  end
end
