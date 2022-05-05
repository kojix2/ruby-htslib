# frozen_string_literal: true

module HTS
  class Bcf < Hts
    class Format
      def initialize(record)
        @record = record
        @p1 = FFI::MemoryPointer.new(:pointer) # FIXME: naming
      end

      # For compatibility with htslib.cr.
      def get_int(key)
        get(key, :int)
      end

      # For compatibility with htslib.cr.
      def get_float(key)
        get(key, :float)
      end

      # For compatibility with htslib.cr.
      def get_flag(key)
        get(key, :flag)
      end

      # For compatibility with htslib.cr.
      def get_string(key)
        get(key, :string)
      end

      def get(key, type = nil)
        n = FFI::MemoryPointer.new(:int)
        p1 = @p1
        h = @record.header.struct
        r = @record.struct

        format_values = proc do |type|
          ret = LibHTS.bcf_get_format_values(h, r, key, p1, n, type)
          return nil if ret < 0 # return from method.

          p1.read_pointer
        end

        type ||= ht_type_to_sym(get_fmt_type(key))

        case type&.to_sym
        when :int, :int32
          format_values.call(LibHTS::BCF_HT_INT)
                       .read_array_of_int32(n.read_int)
        when :float, :real
          format_values.call(LibHTS::BCF_HT_REAL)
                       .read_array_of_float(n.read_int)
        when :flag
          raise NotImplementedError, "Flag type not implemented yet."
          # format_values.call(LibHTS::BCF_HT_FLAG)
          #              .read_int == 1
        when :string, :str
          raise NotImplementedError, "String type not implemented yet."
          # format_values.call(LibHTS::BCF_HT_STR)
          #              .read_string
        end
      end

      def fields
        n_fmt = @record.struct[:n_fmt]
        Array.new(n_fmt) do |i|
          fmt  = LibHTS::BcfFmt.new(@record.struct[:d][:fmt] + i * LibHTS::BcfFmt.size)
          id   = fmt[:id]
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, id)
          num  = LibHTS.bcf_hdr_id2number(@record.header.struct, LibHTS::BCF_HL_FMT, id)
          type = LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_FMT, id)
          {
            name: name,
            n: num,
            type: ht_type_to_sym(type),
            id: id,
          }
        end
      end

      def size
        @record.struct[:n_fmt]
      end

      def to_h
        ret = {}
        @record.struct[:n_fmt].times do |i|
          fmt  = LibHTS::BcfFmt.new(@record.struct[:d][:fmt] + i * LibHTS::BcfFmt.size)
          id   = fmt[:id]
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, id)
          ret[name] = get(name)
        end
        ret
      end

      # def genotypes; end

      private

      def get_fmt_type(qname)
        @record.struct[:n_fmt].times do |i|
          fmt  = LibHTS::BcfFmt.new(@record.struct[:d][:fmt] + i * LibHTS::BcfFmt.size)
          id  = fmt[:id]
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, id)
          if name == qname
            return fmt[:type]
          end
        end
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
