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
        LibHTS.bcf_update_id(@header.struct, @bcf1, id)
      end

      def clear_id
        LibHTS.bcf_update_id(@header.struct, @bcf1, ".")
      end

      def ref
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_STR)
        @bcf1[:d][:allele].get_pointer(0).read_string
      end

      # Return the number of alleles without materializing Ruby strings.
      def allele_count
        @bcf1[:n_allele]
      end

      # Return a pointer to an allele's NUL-terminated bytes.
      #
      # The pointer is borrowed from the record and is only valid until the
      # record is changed, reused by an iterator, or destroyed.
      def allele_pointer_at(index)
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_STR)
        index = Integer(index)
        index += allele_count if index.negative?
        raise ::IndexError, "allele index #{index} outside of record" unless index.between?(0, allele_count - 1)

        @bcf1[:d][:allele].get_pointer(index * FFI::TYPE_POINTER.size)
      end

      # Yield each borrowed allele pointer and its byte length without creating
      # Ruby strings. Pointers have the same lifetime as allele_pointer_at.
      def each_allele_raw
        return to_enum(__method__) unless block_given?

        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_STR)
        pointers = @bcf1[:d][:allele]
        i = 0
        while i < allele_count
          pointer = pointers.get_pointer(i * FFI::TYPE_POINTER.size)
          yield pointer, borrowed_c_string_length(pointer)
          i += 1
        end
        self
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
        when 2..
          d[:flt].get_array_of_int(0, n_flt).map do |i|
            LibHTS.bcf_hdr_int2id(@header.struct, LibHTS::BCF_DT_ID, i)
          end
        else
          raise "Unexpected number of filters. n_flt: #{n_flt}"
        end
      end

      # Yield numeric BCF header IDs for active filters without resolving them
      # to Ruby strings. PASS is normally represented by header ID 0.
      def each_filter_id
        return to_enum(__method__) unless block_given?

        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_FLT)
        d = @bcf1[:d]
        i = 0
        while i < d[:n_flt]
          yield d[:flt].get_int32(i * FFI.type_size(:int32))
          i += 1
        end
        self
      end

      # Materialize the numeric filter IDs into an owning Ruby array.
      def filter_ids
        each_filter_id.to_a
      end

      # Compare an active filter directly by numeric BCF header ID.
      def filter_id?(target_id)
        target_id = Integer(target_id)
        each_filter_id.any? { |id| id == target_id }
      end

      def info(key = nil)
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_SHR)
        info = (@info_accessor ||= Info.new(self))
        if key
          info.get(key)
        else
          info
        end
      end

      def format(key = nil)
        LibHTS.bcf_unpack(@bcf1, LibHTS::BCF_UN_FMT)
        format = (@format_accessor ||= Format.new(self))
        if key
          format.get(key)
        else
          format
        end
      end

      def to_s
        ksr = LibHTS::KString.new
        begin
          raise "Failed to format record" if LibHTS.vcf_format(@header.struct, @bcf1, ksr) == -1

          ksr.read_string_copy
        ensure
          ksr.free_buffer
        end
      end

      private

      def borrowed_c_string_length(pointer)
        length = 0
        length += 1 until pointer.get_uint8(length).zero?
        length
      end

      def initialize_copy(orig)
        @header = orig.header
        @bcf1 = LibHTS.bcf_dup(orig.struct)
        @info_accessor = nil
        @format_accessor = nil
      end
    end
  end
end
