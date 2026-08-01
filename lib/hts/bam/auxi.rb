# frozen_string_literal: true

module HTS
  class Bam < Hts
    class Aux
      include Enumerable
      attr_reader :record

      def initialize(record) = @record = record

      def get(key, type = nil)
        pair = native.aux_get(key, type&.to_s)
        pair&.last
      end

      def get_int(key) = get(key, "i")
      def get_float(key) = get(key, "f")
      def get_string(key) = get(key, "Z")
      def [](key) = get(key)

      def each_array(key, &block)
        return enum_for(__method__, key) unless block_given?

        pair = native.aux_get(key, nil)
        return nil unless pair
        raise TypeError, "AUX tag #{key} is not a B array" unless pair.first.start_with?("B:")

        pair.last.each(&block)
        self
      end

      def []=(key, value)
        case value
        when Integer then update_int(key, value)
        when Float then update_float(key, value)
        when String then update_string(key, value)
        when Array then update_array(key, value)
        else raise ArgumentError, "Unsupported type: #{value.class}"
        end
      end

      def update_int(key, value)
        validate_tag!(key)
        raise "Failed to update integer tag '#{key}'" if native.aux_update_int(key, value.to_i).negative?

        value
      end

      def update_int8(key, value) = update_exact_integer(key, value, "c", -128, 127)
      def update_uint8(key, value) = update_exact_integer(key, value, "C", 0, 255)
      def update_int16(key, value) = update_exact_integer(key, value, "s", -32_768, 32_767)
      def update_uint16(key, value) = update_exact_integer(key, value, "S", 0, 65_535)
      def update_int32(key, value) = update_exact_integer(key, value, "i", -2_147_483_648, 2_147_483_647)
      def update_uint32(key, value) = update_exact_integer(key, value, "I", 0, 4_294_967_295)

      def update_float(key, value)
        validate_tag!(key)
        raise "Failed to update float tag '#{key}'" if native.aux_update_float(key, value.to_f).negative?

        value
      end

      def update_string(key, value)
        validate_tag!(key)
        string = value.to_s
        validate_string_value!(string)
        raise "Failed to update string tag '#{key}'" if native.aux_update_string(key, string).negative?

        string
      end

      def update_char(key, value)
        validate_tag!(key)
        string = value.to_s
        validate_char_value!(string)
        replace_with_append(key, "A", string.b)
        string
      end

      def update_hex(key, value)
        validate_tag!(key)
        string = value.to_s
        validate_hex_value!(string)
        replace_with_append(key, "H", string.b + "\0")
        string
      end

      def update_double(key, value)
        validate_tag!(key)
        replace_with_append(key, "d", [Float(value)].pack("E"))
        value.to_f
      end

      def update_array(key, value, type: nil)
        validate_tag!(key)
        raise ArgumentError, "Array cannot be empty" if value.empty?

        type ||= if value.all? { |item| item.is_a?(Integer) }
                   "i"
                 elsif value.all? { |item| item.is_a?(Numeric) }
                   "f"
                 else
                   raise ArgumentError, "Array must contain only integers or floats"
                 end
        validate_array!(value, type)
        raise "Failed to update array tag '#{key}'" if native.aux_update_array(key, type, value).negative?

        value
      end

      def delete(key) = native.aux_delete(key)
      def key?(key) = native.aux_key?(key)
      alias include? key?

      def first = entries.first&.last

      def each_value
        return enum_for(__method__) unless block_given?

        entries.each { |_, _, value| yield value }
      end

      def each
        return enum_for(__method__) unless block_given?

        entries.each { |tag, _, value| yield tag, value }
      end
      alias each_pair each

      def each_tag_id
        return enum_for(__method__) unless block_given?

        entries.each { |tag, _, value| yield self.class.tag_id(tag), value }
        self
      end

      def self.tag_id(tag)
        raise ArgumentError, "AUX tag must be a 2-byte String" unless tag.is_a?(String) && tag.bytesize == 2

        tag.getbyte(0) | (tag.getbyte(1) << 8)
      end

      def each_with_type(&block)
        return enum_for(__method__) unless block_given?

        entries.each(&block)
      end

      def to_h = entries.to_h { |tag, _, value| [tag, value] }

      private

      def native = @record.__send__(:native_handle)
      def entries = native.aux_entries

      def validate_tag!(key)
        return if key.is_a?(String) && key.bytesize == 2 && key.ascii_only?

        raise ArgumentError, "AUX tag must be a 2-byte ASCII String"
      end

      def validate_string_value!(string)
        raise ArgumentError, "String AUX tags must not contain NUL bytes" if string.include?("\0")
      end

      def validate_char_value!(string)
        return if string.bytesize == 1 && string.ascii_only? && /\A[!-~]\z/.match?(string)

        raise ArgumentError, "Character AUX tags must be a single printable ASCII byte"
      end

      def validate_hex_value!(string)
        raise ArgumentError, "Hex AUX tags must contain an even number of characters" if string.bytesize.odd?
        return if string.ascii_only? && /\A[0-9A-Fa-f]*\z/.match?(string)

        raise ArgumentError, "Hex AUX tags must contain only ASCII hexadecimal characters"
      end

      def update_exact_integer(key, value, type, min, max)
        validate_tag!(key)
        integer = Integer(value)
        raise RangeError, "Value #{integer} is out of range for AUX type #{type}" unless integer.between?(min, max)

        payload = case type
                  when "c" then [integer].pack("c")
                  when "C" then [integer].pack("C")
                  when "s" then [integer].pack("s<")
                  when "S" then [integer].pack("S<")
                  when "i" then [integer].pack("l<")
                  when "I" then [integer].pack("L<")
                  end
        replace_with_append(key, type, payload)
        integer
      end

      def replace_with_append(key, type, payload)
        delete(key)
        raise "Failed to update #{type} tag '#{key}'" if native.aux_append(key, type, payload).negative?
      end

      def validate_array!(value, type)
        ranges = {
          "c" => (-128..127), "C" => (0..255), "s" => (-32_768..32_767),
          "S" => (0..65_535), "i" => (-2_147_483_648..2_147_483_647),
          "I" => (0..4_294_967_295)
        }
        if (range = ranges[type])
          value.each do |element|
            integer = Integer(element)
            unless range.cover?(integer)
              raise RangeError,
                    "Array element #{integer} is out of range for AUX array type #{type}"
            end
          end
        elsif type == "f"
          value.each { |element| Float(element) }
        else
          raise ArgumentError, "Invalid array type: #{type}"
        end
      end
    end
  end
end
