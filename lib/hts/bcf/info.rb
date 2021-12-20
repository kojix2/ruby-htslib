# frozen_string_literal: true

module HTS
  class Bcf
    class Info
      def initialize(record)
        @record = record
      end

      def get(key, type = nil)
        n = FFI::MemoryPointer.new(:int)
        p1 = @record.p1
        p2 = FFI::MemoryPointer.new(:pointer).write_pointer(p1)
        h = @record.bcf.header.struct
        r = @record.struct

        info_values = proc do |type|
          ret = LibHTS.bcf_get_info_values(h, r, key, p2, n, type)
          return nil if ret < 0 # return from method.
        end

        case type.to_sym
        when :int, :int32
          info_values.call(LibHTS::BCF_HT_INT)
          p1.read_array_of_int32(n.read_int)
        when :float, :real
          info_values.call(LibHTS::BCF_HT_REAL)
          p1.read_array_of_float(n.read_int)
        when :flag
          info_values.call(LibHTS::BCF_HT_FLAG)
          p1.read_int == 1
        when :string, :str
          info_values.call(LibHTS::BCF_HT_STR)
          p1.read_pointer.read_string
        end
      end
    end
  end
end
