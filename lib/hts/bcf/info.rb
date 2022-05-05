# frozen_string_literal: true

module HTS
  class Bcf < Hts
    class Info
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
      def get_string(key)
        get(key, :string)
      end

      # For compatibility with htslib.cr.
      def get_flag(key)
        get(key, :flag)
      end

      # @note Specify the type. If you don't specify a type, it will still work, but it will be slower.
      def get(key, type = nil)
        n = FFI::MemoryPointer.new(:int)
        p1 = @p1
        h = @record.header.struct
        r = @record.struct

        info_values = proc do |typ|
          ret = LibHTS.bcf_get_info_values(h, r, key, p1, n, typ)
          return nil if ret < 0 # return from method.

          p1.read_pointer
        end

        type ||= ht_type_to_sym(get_info_type(key))

        case type&.to_sym
        when :int, :int32
          info_values.call(LibHTS::BCF_HT_INT)
                     .read_array_of_int32(n.read_int)
        when :float, :real
          info_values.call(LibHTS::BCF_HT_REAL)
                     .read_array_of_float(n.read_int)
        when :flag, :bool
          case ret = LibHTS.bcf_get_info_flag(h, r, key, p1, n)
          when 1 then true
          when 0 then false
          when -1 then nil
          else
            raise "Unknown return value from bcf_get_info_flag: #{ret}"
          end
        when :string, :str
          info_values.call(LibHTS::BCF_HT_STR)
                     .read_string
        end
      end

      # FIXME: naming? room for improvement.
      def fields
        keys.map do |key|
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, key)
          num  = LibHTS.bcf_hdr_id2number(@record.header.struct, LibHTS::BCF_HL_INFO, key)
          type = LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_INFO, key)
          {
            name: name,
            n: num,
            type: ht_type_to_sym(type),
            key: key
          }
        end
      end

      def size
        @record.struct[:n_info]
      end

      def to_h
        ret = {}
        keys.each do |key|
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, key)
          ret[name] = get(name)
        end
        ret
      end

      private

      def fmt_ptr
        @record.struct[:d][:info].to_ptr
      end

      def keys
        fmt_ptr.read_array_of_struct(LibHTS::BcfInfo, size).map do |info|
          info[:key]
        end
      end

      def get_info_type(key)
        @record.struct[:n_info].times do |i|
          info = LibHTS::BcfInfo.new(@record.struct[:d][:info] + i * LibHTS::BcfInfo.size)
          k = info[:key]
          id = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, k)
          if id == key
            type = LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_INFO, k)
            return type
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
