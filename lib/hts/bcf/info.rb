# frozen_string_literal: true

module HTS
  class Bcf
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

        info_values = proc do |type|
          ret = LibHTS.bcf_get_info_values(h, r, key, p1, n, type)
          return nil if ret < 0 # return from method.

          p1.read_pointer
        end

        type ||= info_type_to_string(get_info_type(key))

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
        n_info = @record.struct[:n_info]
        Array.new(n_info) do |i|
          fld = LibHTS::BcfInfo.new(
            @record.struct[:d][:info] +
            i * LibHTS::BcfInfo.size
          )
          {
            name: LibHTS.bcf_hdr_int2id(
              @record.header.struct, LibHTS::BCF_DT_ID, fld[:key]
            ),
            n: LibHTS.bcf_hdr_id2number(
              @record.header.struct, LibHTS::BCF_HL_INFO, fld[:key]
            ),
            vtype: fld[:type], i: fld[:key]
          }
        end
      end

      private

      def get_info_type(key)
        @record.struct[:n_info].times do |i|
          fld = LibHTS::BcfInfo.new(
            @record.struct[:d][:info] +
            i * LibHTS::BcfInfo.size
          )
          id = LibHTS.bcf_hdr_int2id(
            @record.header.struct, LibHTS::BCF_DT_ID, fld[:key]
          )
          return fld[:type] if id == key
        end
      end

      def info_type_to_string(t)
        case t
        when 0 then :flag
        when 1, 2, 3, 4 then :int
        when 5 then :float
        when 7 then :string
        else
          raise "Unknown info type: #{t}"
        end
      end
    end
  end
end
