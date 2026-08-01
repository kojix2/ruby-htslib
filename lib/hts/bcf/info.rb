# frozen_string_literal: true

module HTS
  class Bcf < Hts
    # Info field
    class Info
      def initialize(record)
        @record = record
        @buffers = {}
        @schema_cache = {}
        @schema_version = record.header.schema_version
      end

      # @note Specify the type. If you don't specify a type, it will still work, but it will be slower.
      # @note: Why is this method named "get" instead of "fetch"?
      # This is for compatibility with the Crystal language
      # which provides methods like `get_int`, `get_float`, etc.
      # I think they are better than `fetch_int`` and `fetch_float`.
      def get(key, type = nil)
        h = @record.header.struct
        r = @record.struct

        actual_type = ht_type_to_sym(get_info_type(key))
        if type && actual_type && !info_type_compatible?(actual_type, type.to_sym)
          raise InfoTypeError, "Tag #{key} is not #{type_label(type)} INFO field"
        end

        type ||= actual_type

        case type&.to_sym
        when :int, :int32
          read_values(h, r, key, LibHTS::BCF_HT_INT) { |dst, count| dst.read_array_of_int32(count) }
        when :int64, :long
          read_values(h, r, key, LibHTS::BCF_HT_LONG) { |dst, count| dst.read_array_of_int64(count) }
        when :float, :real
          read_values(h, r, key, LibHTS::BCF_HT_REAL) { |dst, count| dst.read_array_of_float(count) }
        when :flag, :bool
          buffer = buffer_for(LibHTS::BCF_HT_FLAG)
          case ret = LibHTS.bcf_get_info_flag(h, r, key, buffer.dst_pointer, buffer.capacity_pointer)
          when 1 then true
          when 0, -1, -3 then nil
          else
            raise InfoReadError, "Unknown return value from bcf_get_info_flag: #{ret}"
          end
        when :string, :str
          read_values(h, r, key, LibHTS::BCF_HT_STR) { |dst, _count| dst.read_string }
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
            raise RangeError,
                  "Integer out of int32 range for []=. Current htslib backend does not support int64 INFO update."
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
              raise RangeError,
                    "Integer array contains out-of-int32 values for []=. Current htslib backend does not support int64 INFO update."
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
        raise InfoUpdateError, "Failed to update INFO int field '#{key}': #{ret}" if ret < 0

        ret
      end

      # Update INFO field with int64 value(s).
      # @note int64 INFO values are primarily relevant for VCF output.
      # @param key [String] INFO tag name
      # @param values [Array<Integer>] integer values (use single-element array for scalar)
      def update_int64(_key, _values)
        raise UnsupportedInfoOperationError, "htslib backend does not implement int64 INFO update (BCF_HT_LONG)"
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
        raise InfoUpdateError, "Failed to update INFO float field '#{key}': #{ret}" if ret < 0

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
        raise InfoUpdateError, "Failed to update INFO string field '#{key}': #{ret}" if ret < 0

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
        raise InfoUpdateError, "Failed to update INFO flag field '#{key}': #{ret}" if ret < 0

        ret
      end

      # Delete an INFO field.
      # @param key [String] INFO tag name
      # @return [Boolean] true if field was deleted, false if it didn't exist
      def delete(key)
        type = get_info_type(key)
        return false if type.nil?
        return false unless key?(key)

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
        type = header_info_type(key)
        return false if type.nil?

        ndst = FFI::MemoryPointer.new(:int)
        ndst.write_int(0)
        dst_ptr = FFI::MemoryPointer.new(:pointer)
        dst_ptr.write_pointer(FFI::Pointer::NULL)

        ret = LibHTS.bcf_get_info_values(@record.header.struct, @record.struct, key, dst_ptr, ndst, type)
        type == LibHTS::BCF_HT_FLAG ? ret == 1 : ret >= 0
      ensure
        if dst_ptr
          dst = dst_ptr.read_pointer
          LibHTS.hts_free(dst) unless dst.null?
        end
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

      def read_values(header, record, key, type)
        buffer = buffer_for(type)
        count = LibHTS.bcf_get_info_values(
          header, record, key, buffer.dst_pointer, buffer.capacity_pointer, type
        )
        return nil if count.negative?

        # The return value is the number of values. ndst is allocation capacity
        # and may be larger after a previous call using this reusable buffer.
        yield(buffer.pointer, count)
      end

      def buffer_for(type)
        @buffers[type] ||= GetterBuffer.new
      end

      def info_ptr
        @record.struct[:d][:info].to_ptr
      end

      def keys
        info_ptr.read_array_of_struct(LibHTS::BcfInfo, length).map do |info|
          info[:key]
        end
      end

      def get_info_type(key)
        header_info_type(key)
      end

      def header_info_type(key)
        refresh_schema_cache!
        return @schema_cache[key] if @schema_cache.key?(key)

        id = LibHTS.bcf_hdr_id2int(@record.header.struct, LibHTS::BCF_DT_ID, key)
        return @schema_cache[key] = nil if id.negative?
        unless LibHTS.bcf_hdr_idinfo_exists(@record.header.struct, LibHTS::BCF_HL_INFO, id)
          return @schema_cache[key] = nil
        end

        @schema_cache[key] = LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_INFO, id)
      end

      def refresh_schema_cache!
        version = @record.header.schema_version
        return if version == @schema_version

        @schema_cache.clear
        @schema_version = version
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

      def info_type_compatible?(actual_type, requested_type)
        case requested_type
        when :int, :int32
          actual_type == :int
        when :int64, :long
          %i[int int64].include?(actual_type)
        when :float, :real
          actual_type == :float
        when :flag, :bool
          actual_type == :flag
        when :string, :str
          actual_type == :string
        else
          actual_type == requested_type
        end
      end

      def type_label(type)
        case type.to_sym
        when :int, :int32 then "integer"
        when :int64, :long then "integer"
        when :float, :real then "float"
        when :flag, :bool then "flag"
        when :string, :str then "string"
        else type.to_s
        end
      end
    end
  end
end
