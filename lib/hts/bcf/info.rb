# frozen_string_literal: true

module HTS
  class Bcf < Hts
    # Info field
    class Info
      def initialize(record)
        @record = record
      end

      # @note Specify the type. If you don't specify a type, it will still work, but it will be slower.
      # @note: Why is this method named "get" instead of "fetch"?
      # This is for compatibility with the Crystal language
      # which provides methods like `get_int`, `get_float`, etc.
      # I think they are better than `fetch_int`` and `fetch_float`.
      def get(key, type = nil)
        n = FFI::MemoryPointer.new(:int)
        p1 = FFI::MemoryPointer.new(:pointer)
        p1.write_pointer(FFI::Pointer::NULL)
        h = @record.header.struct
        r = @record.struct

        info_values = proc do |typ, reader|
          ret = LibHTS.bcf_get_info_values(h, r, key, p1, n, typ)
          return nil if ret < 0 # return from method.

          dst = p1.read_pointer
          begin
            reader.call(dst, n.read_int)
          ensure
            LibHTS.hts_free(dst) unless dst.null?
            p1.write_pointer(FFI::Pointer::NULL)
          end
        end

        type ||= ht_type_to_sym(get_info_type(key))

        case type&.to_sym
        when :int, :int32
          info_values.call(LibHTS::BCF_HT_INT, ->(dst, len) { dst.read_array_of_int32(len) })
        when :int64, :long
          info_values.call(LibHTS::BCF_HT_LONG, ->(dst, len) { dst.read_array_of_int64(len) })
        when :float, :real
          info_values.call(LibHTS::BCF_HT_REAL, ->(dst, len) { dst.read_array_of_float(len) })
        when :flag, :bool
          begin
            case ret = LibHTS.bcf_get_info_flag(h, r, key, p1, n)
            when 1 then true
            when 0 then false
            when -1 then nil
            else
              raise "Unknown return value from bcf_get_info_flag: #{ret}"
            end
          ensure
            dst = p1.read_pointer
            LibHTS.hts_free(dst) unless dst.null?
            p1.write_pointer(FFI::Pointer::NULL)
          end
        when :string, :str
          info_values.call(LibHTS::BCF_HT_STR, ->(dst, _len) { dst.read_string })
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
      def get_int64(key)
        get(key, :int64)
      end

      # For compatibility with HTS.cr.
      def get_string(key)
        get(key, :string)
      end

      # For compatibility with HTS.cr.
      def get_flag(key)
        get(key, :flag)
      end

      def [](key)
        get(key)
      end

      # Set INFO field value with automatic type detection.
      # @param key [String] INFO tag name
      # @param value [Integer, Float, String, Array, true, false, nil] value to set
      #   - Integer or Array<Integer> -> update_int
      #   - Float or Array<Float,Integer> -> update_float
      #   - String -> update_string
      #   - true/false -> update_flag
      #   - nil -> delete the INFO field
      def []=(key, value)
        case value
        when nil
          delete(key)
        when true, false
          update_flag(key, value)
        when Integer
          unless int32_range?(value)
            raise RangeError, "Integer out of int32 range for []=. Current htslib backend does not support int64 INFO update."
          end
          update_int(key, [value])
        when Float
          update_float(key, [value])
        when String
          update_string(key, value)
        when Array
          if value.empty?
            raise ArgumentError, "Cannot set INFO field to empty array. Use nil to delete."
          elsif value.all? { |v| v.is_a?(Integer) }
            unless value.all? { |v| int32_range?(v) }
              raise RangeError, "Integer array contains out-of-int32 values for []=. Current htslib backend does not support int64 INFO update."
            end
            update_int(key, value)
          elsif value.all? { |v| v.is_a?(Numeric) }
            update_float(key, value)
          else
            raise ArgumentError, "INFO array must contain only integers or floats, got: #{value.map(&:class).uniq}"
          end
        else
          raise ArgumentError, "Unsupported INFO value type: #{value.class}"
        end
      end

      # Update INFO field with integer value(s).
      # For compatibility with HTS.cr.
      # @param key [String] INFO tag name
      # @param values [Array<Integer>] integer values (use single-element array for scalar)
      def update_int(key, values)
        values = Array(values)
        ptr = FFI::MemoryPointer.new(:int32, values.size)
        ptr.write_array_of_int32(values)
        ret = LibHTS.bcf_update_info(
          @record.header.struct,
          @record.struct,
          key,
          ptr,
          values.size,
          LibHTS::BCF_HT_INT
        )
        raise "Failed to update INFO int field '#{key}': #{ret}" if ret < 0

        ret
      end

      # Update INFO field with int64 value(s).
      # @note int64 INFO values are primarily relevant for VCF output.
      # @param key [String] INFO tag name
      # @param values [Array<Integer>] integer values (use single-element array for scalar)
      def update_int64(key, values)
        raise NotImplementedError, "htslib backend does not implement int64 INFO update (BCF_HT_LONG)"
      end

      # Update INFO field with float value(s).
      # For compatibility with HTS.cr.
      # @param key [String] INFO tag name
      # @param values [Array<Float>] float values (use single-element array for scalar)
      def update_float(key, values)
        values = Array(values).map(&:to_f)
        ptr = FFI::MemoryPointer.new(:float, values.size)
        ptr.write_array_of_float(values)
        ret = LibHTS.bcf_update_info(
          @record.header.struct,
          @record.struct,
          key,
          ptr,
          values.size,
          LibHTS::BCF_HT_REAL
        )
        raise "Failed to update INFO float field '#{key}': #{ret}" if ret < 0

        ret
      end

      # Update INFO field with string value.
      # For compatibility with HTS.cr.
      # @param key [String] INFO tag name
      # @param value [String] string value
      def update_string(key, value)
        ret = LibHTS.bcf_update_info(
          @record.header.struct,
          @record.struct,
          key,
          value.to_s,
          1,
          LibHTS::BCF_HT_STR
        )
        raise "Failed to update INFO string field '#{key}': #{ret}" if ret < 0

        ret
      end

      # Update INFO flag field.
      # For compatibility with HTS.cr.
      # @param key [String] INFO tag name
      # @param present [Boolean] true to set flag, false to remove it
      def update_flag(key, present = true)
        ret = if present
                LibHTS.bcf_update_info(
                  @record.header.struct,
                  @record.struct,
                  key,
                  FFI::Pointer::NULL,
                  1,
                  LibHTS::BCF_HT_FLAG
                )
              else
                # Remove flag by setting n=0
                LibHTS.bcf_update_info(
                  @record.header.struct,
                  @record.struct,
                  key,
                  FFI::Pointer::NULL,
                  0,
                  LibHTS::BCF_HT_FLAG
                )
              end
        raise "Failed to update INFO flag field '#{key}': #{ret}" if ret < 0

        ret
      end

      # Delete an INFO field.
      # @param key [String] INFO tag name
      # @return [Boolean] true if field was deleted, false if it didn't exist
      def delete(key)
        # Try to get current type to check existence
        type = get_info_type(key)
        return false if type.nil?

        # Delete by setting n=0
        ret = LibHTS.bcf_update_info(
          @record.header.struct,
          @record.struct,
          key,
          FFI::Pointer::NULL,
          0,
          type
        )
        return false if ret < 0

        true
      end

      # Check if an INFO field exists.
      # @param key [String] INFO tag name
      # @return [Boolean] true if the field exists
      def key?(key)
        # Use get() to check if value is actually present
        # (get_info_type only checks header, not actual value)
        !get(key).nil?
      end

      alias include? key?

      # FIXME: naming? room for improvement.
      def fields
        keys.map do |key|
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, key)
          num  = LibHTS.bcf_hdr_id2number(@record.header.struct, LibHTS::BCF_HL_INFO, key)
          type = LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_INFO, key)
          {
            name:,
            n: num,
            type: ht_type_to_sym(type),
            key:
          }
        end
      end

      def length
        @record.struct[:n_info]
      end

      def size
        length
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

      def info_ptr
        @record.struct[:d][:info].to_ptr
      end

      def keys
        info_ptr.read_array_of_struct(LibHTS::BcfInfo, length).map do |info|
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
        nil
      end

      def ht_type_to_sym(t)
        case t
        when LibHTS::BCF_HT_FLAG then :flag
        when LibHTS::BCF_HT_INT then :int
        when LibHTS::BCF_HT_REAL then :float
        when LibHTS::BCF_HT_STR then :string
        when LibHTS::BCF_HT_LONG then :int64
        end
      end

      def int32_range?(value)
        value >= -2_147_483_648 && value <= 2_147_483_647
      end
    end
  end
end
