# frozen_string_literal: true

require 'ffi/bit_struct'

module FFI
  class Struct
    class << self
      # @example HtsOpt
      #   class HtsOpt < FFI::Struct
      #     layout \
      #       :arg,            :string,
      #       :opt,            HtsFmtOption,
      #       :val,
      #       union_layout(
      #         :i,            :int,
      #         :s,            :string
      #       ),
      #       :next,           HtsOpt.ptr
      #   end

      def union_layout(*args)
        Class.new(FFI::Union) { layout(*args) }
      end

      # @example HtsFormat
      #   class HtsFormat < FFI::Struct
      #     layout \
      #       :category,          HtsFormatCategory,
      #       :format,            HtsExactFormat,
      #       :version,
      #       struct_layout(
      #         :major,           :short,
      #         :minor,           :short
      #       ),
      #       :compression,       HtsCompression,
      #       :compression_level, :short,
      #       :specific,          :pointer
      #   end

      def struct_layout(*args)
        Class.new(FFI::Struct) { layout(*args) }
      end
    end
  end
end
