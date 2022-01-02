# frozen_string_literal: true

# https://github.com/brentp/hts-nim/blob/master/src/hts/vcf.nim
# This is a port from Nim.
# TODO: Make it more like Ruby.

module HTS
  class Bcf
    class Format
      def initialize(record)
        @record = record
        @p1 = FFI::MemoryPointer.new(:pointer) # FIXME: naming
      end

      def get(key, type = nil)
        n = FFI::MemoryPointer.new(:int)
        p1 = @p1
        h = @record.bcf.header.struct
        r = @record.struct

        format_values = proc do |type|
          ret = LibHTS.bcf_get_format_values(h, r, key, p1, n, type)
          return nil if ret < 0 # return from method.

          p1.read_pointer
        end

        case type.to_sym
        when :int, :int32
          format_values.call(LibHTS::BCF_HT_INT)
                       .read_array_of_int32(n.read_int)
        when :float, :real
          format_values.call(LibHTS::BCF_HT_REAL)
                       .read_array_of_float(n.read_int)
        when :flag
          format_values.call(LibHTS::BCF_HT_FLAG)
                       .read_int == 1
        when :string, :str
          raise NotImplementedError, "String type not implemented yet."
          format_values.call(LibHTS::BCF_HT_STR)
                       .read_string
        end
      end

      def set; end

      # def fields # iterator
      # end

      def genotypes; end
    end
  end
end
