# frozen_string_literal: true

module HTS
  class Bcf < Hts
    class Info
      TYPE_CODES = {
        flag: Native::BCF_HT_FLAG, bool: Native::BCF_HT_FLAG,
        int: Native::BCF_HT_INT, int32: Native::BCF_HT_INT,
        int64: Native::BCF_HT_LONG, long: Native::BCF_HT_LONG,
        float: Native::BCF_HT_REAL, real: Native::BCF_HT_REAL,
        string: Native::BCF_HT_STR, str: Native::BCF_HT_STR
      }.freeze

      def initialize(record) = @record = record

      def get(key, type = nil)
        schema = header.schema("INFO", key.to_s)
        return nil unless schema

        actual_type = schema.first
        requested = type&.to_sym
        if requested && !type_compatible?(actual_type, requested)
          raise InfoTypeError, "Tag #{key} is not #{type_label(requested)} INFO field"
        end

        code = TYPE_CODES.fetch(requested || actual_type)
        native.info_get(header_native, key.to_s, code)
      end

      def get_int(key) = get(key, :int)
      def get_float(key) = get(key, :float)
      def get_int64(key) = get(key, :int64)
      def get_string(key) = get(key, :string)
      def get_flag(key) = get(key, :flag)
      def [](key) = get(key)

      def []=(key, value)
        case value
        when nil then delete(key)
        when true, false then update_flag(key, value)
        when Integer
          unless int32?(value)
            raise RangeError,
                  "Integer out of int32 range for []=. Current htslib backend does not support int64 INFO update."
          end

          update_int(key, [value])
        when Float then update_float(key, [value])
        when String then update_string(key, value)
        when Array
          raise ArgumentError, "Cannot set INFO field to empty array. Use nil to delete." if value.empty?

          if value.all? { |item| item.is_a?(Integer) }
            unless value.all? do |item|
              int32?(item)
            end
              raise RangeError,
                    "Integer array contains out-of-int32 values for []=. Current htslib backend does not support int64 INFO update."
            end

            update_int(key, value)
          elsif value.all? { |item| item.is_a?(Numeric) }
            update_float(key, value)
          else
            raise ArgumentError, "INFO array must contain only integers or floats, got: #{value.map(&:class).uniq}"
          end
        else raise ArgumentError, "Unsupported INFO value type: #{value.class}"
        end
      end

      def update_int(key, values) = update(key, Native::BCF_HT_INT, Array(values).map { |value| Integer(value) }, "int")
      def update_float(key, values) = update(key, Native::BCF_HT_REAL, Array(values).map(&:to_f), "float")
      def update_string(key, value) = update(key, Native::BCF_HT_STR, value.to_s, "string")

      def update_int64(_key,
                       _values) = raise(UnsupportedInfoOperationError,
                                        "htslib backend does not implement int64 INFO update (BCF_HT_LONG)")

      def update_flag(key, present = true) = update(key, Native::BCF_HT_FLAG, !!present, "flag")

      def delete(key)
        schema = header.schema("INFO", key.to_s)
        return false unless schema && key?(key)

        native.info_update(header_native, key.to_s, TYPE_CODES.fetch(schema.first), false)
        true
      end

      def key?(key)
        schema = header.schema("INFO", key.to_s)
        schema ? native.info_present?(header_native, key.to_s, TYPE_CODES.fetch(schema.first)) : false
      end
      alias include? key?

      def fields = native.info_fields(header_native)
      def keys = fields.map { |field| field[:key] }
      def length = fields.length
      alias size length
      def to_h = fields.to_h { |field| [field[:name], get(field[:name])] }

      private

      def native = @record.__send__(:native_handle)
      def header = @record.header.__send__(:native_handle)
      alias header_native header

      def update(key, type, value, label)
        result = native.info_update(header_native, key.to_s, type, value)
        raise InfoUpdateError, "Failed to update INFO #{label} field '#{key}': #{result}" if result.negative?

        result
      end

      def type_compatible?(actual, requested)
        case requested
        when :int, :int32 then actual == :int
        when :int64, :long then %i[int int64].include?(actual)
        when :float, :real then actual == :float
        when :flag, :bool then actual == :flag
        when :string, :str then actual == :string
        else actual == requested
        end
      end

      def type_label(type)
        case type
        when :int, :int32, :int64, :long then "integer"
        when :float, :real then "float"
        when :flag, :bool then "flag"
        when :string, :str then "string"
        else type.to_s
        end
      end

      def int32?(value) = value.between?(-2_147_483_648, 2_147_483_647)
    end
  end
end
