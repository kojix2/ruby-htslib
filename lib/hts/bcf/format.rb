# frozen_string_literal: true

module HTS
  class Bcf < Hts
    class Format
      def initialize(record)
        @record = record
        @p1 = FFI::MemoryPointer.new(:pointer) # FIXME: naming
      end

      # @note: Why is this method named "get" instead of "fetch"?
      # This is for compatibility with the Crystal language
      # which provides methods like `get_int`, `get_float`, etc.
      # I think they are better than `fetch_int`` and `fetch_float`.
      def get(key, type = nil)
        n = FFI::MemoryPointer.new(:int)
        p1 = @p1
        h = @record.header.struct
        r = @record.struct

        format_values = proc do |typ|
          ret = LibHTS.bcf_get_format_values(h, r, key, p1, n, typ)
          return nil if ret < 0 # return from method.

          p1.read_pointer
        end

        # The GT FORMAT field is special in that it is marked as a string in the header,
        # but it is actually encoded as an integer.
        if key == "GT"
          type = :int
        elsif type.nil?
          type = ht_type_to_sym(get_fmt_type(key))
        end

        case type&.to_sym
        when :int, :int32
          format_values.call(LibHTS::BCF_HT_INT)
                       .read_array_of_int32(n.read_int)
        when :float, :real
          format_values.call(LibHTS::BCF_HT_REAL)
                       .read_array_of_float(n.read_int)
        when :flag
          raise NotImplementedError, "Flag type not implemented yet. " \
          "Please file an issue on GitHub."
          # format_values.call(LibHTS::BCF_HT_FLAG)
          #              .read_int == 1
        when :string, :str
          raise NotImplementedError, "String type not implemented yet. " \
          "Please file an issue on GitHub."
          # format_values.call(LibHTS::BCF_HT_STR)
          #              .read_string
        end
      end

      # For compatibility with HTS.cr.
      def get_int(key)
        get(key, :int)
      end

      # For compatibility with HTS.cr.
      def get_float(key)
        get(key, :float)
      end

      # For compatibility with HTS.cr.
      def get_flag(key)
        get(key, :flag)
      end

      # For compatibility with HTS.cr.
      def get_string(key)
        get(key, :string)
      end

      def [](key)
        get(key)
      end

      def fields
        ids.map do |id|
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, id)
          num  = LibHTS.bcf_hdr_id2number(@record.header.struct, LibHTS::BCF_HL_FMT, id)
          type = LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_FMT, id)
          {
            name:,
            n: num,
            type: ht_type_to_sym(type),
            id:
          }
        end
      end

      def length
        @record.struct[:n_fmt]
      end

      def size
        length
      end

      def to_h
        ret = {}
        ids.each do |id|
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, id)
          ret[name] = get(name)
        end
        ret
      end

      # def genotypes; end

      private

      def fmt_ptr
        @record.struct[:d][:fmt].to_ptr
      end

      def ids
        fmt_ptr.read_array_of_struct(LibHTS::BcfFmt, length).map do |fmt|
          fmt[:id]
        end
      end

      def get_fmt_type(qname)
        @record.struct[:n_fmt].times do |i|
          fmt = LibHTS::BcfFmt.new(@record.struct[:d][:fmt] + i * LibHTS::BcfFmt.size)
          id = fmt[:id]
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, id)
          if name == qname
            type = LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_FMT, id)
            return type
          end
        end
        nil
      end

      def ht_type_to_sym(t)
        case t
        when LibHTS::BCF_HT_FLAG then :flag
        when LibHTS::BCF_HT_INT then :int
        when LibHTS::BCF_HT_REAL then :float
        when LibHTS::BCF_HT_STR then :string
        when LibHTS::BCF_HT_LONG then :float
        end
      end
    end
  end
end
