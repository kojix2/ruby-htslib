# frozen_string_literal: true

# Q. Why is the file name auxi.rb and not aux.rb?
#
# A. This is for compatibility with Windows.
#
# In Windows, aux is a reserved word
# You cannot create a file named aux.
#
# What?! That's crazy!

module HTS
  class Bam < Hts
    # Auxiliary record data
    #
    # @noge Aux is a View object.
    # The result of the alignment is assigned to the bam1 structure.
    # Ruby's Aux class references a part of it. There is no one-to-one
    # correspondence between C structures and Ruby's Aux class.
    class Aux
      include Enumerable
      attr_reader :record

      def initialize(record)
        @record = record
      end

      # @note Why is this method named "get" instead of "fetch"?
      # This is for compatibility with the Crystal language
      # which provides methods like `get_int`, `get_float`, etc.
      # I think they are better than `fetch_int`` and `fetch_float`.
      def get(key, type = nil)
        aux_ptr = LibHTS.bam_aux_get(@record.struct, key)
        return nil if aux_ptr.null?

        get_ruby_aux(aux_ptr, type)
      end

      # For compatibility with HTS.cr.
      def get_int(key)
        get(key, "i")
      end

      # For compatibility with HTS.cr.
      def get_float(key)
        get(key, "f")
      end

      # For compatibility with HTS.cr.
      def get_string(key)
        get(key, "Z")
      end

      def [](key)
        get(key)
      end

      # Set auxiliary tag value (auto-detects type from value)
      # For compatibility with HTS.cr.
      # @param key [String] tag name (2 characters)
      # @param value [Integer, Float, String, Array] tag value
      def []=(key, value)
        case value
        when Integer
          update_int(key, value)
        when Float
          update_float(key, value)
        when String
          update_string(key, value)
        when Array
          update_array(key, value)
        else
          raise ArgumentError, "Unsupported type: #{value.class}"
        end
      end

      # Update or add an integer tag
      # For compatibility with HTS.cr.
      # @param key [String] tag name (2 characters)
      # @param value [Integer] integer value
      def update_int(key, value)
        ret = LibHTS.bam_aux_update_int(@record.struct, key, value.to_i)
        raise "Failed to update integer tag '#{key}': errno #{FFI.errno}" if ret < 0

        value
      end

      # Update or add a floating-point tag
      # For compatibility with HTS.cr.
      # @param key [String] tag name (2 characters)
      # @param value [Float] floating-point value
      def update_float(key, value)
        ret = LibHTS.bam_aux_update_float(@record.struct, key, value.to_f)
        raise "Failed to update float tag '#{key}': errno #{FFI.errno}" if ret < 0

        value
      end

      # Update or add a string tag
      # For compatibility with HTS.cr.
      # @param key [String] tag name (2 characters)
      # @param value [String] string value
      def update_string(key, value)
        ret = LibHTS.bam_aux_update_str(@record.struct, key, -1, value.to_s)
        raise "Failed to update string tag '#{key}': errno #{FFI.errno}" if ret < 0

        value
      end

      # Update or add an array tag
      # For compatibility with HTS.cr.
      # @param key [String] tag name (2 characters)
      # @param value [Array] array of integers or floats
      # @param type [String, nil] element type ('c', 'C', 's', 'S', 'i', 'I', 'f'). Auto-detected if nil.
      def update_array(key, value, type: nil)
        raise ArgumentError, "Array cannot be empty" if value.empty?

        # Auto-detect type if not specified
        if type.nil?
          if value.all? { |v| v.is_a?(Integer) }
            # Use 'i' for signed 32-bit integers by default
            type = "i"
          elsif value.all? { |v| v.is_a?(Float) || v.is_a?(Integer) }
            type = "f"
          else
            raise ArgumentError, "Array must contain only integers or floats"
          end
        end

        # Convert array to appropriate C type
        case type
        when "c", "C", "s", "S", "i", "I"
          # Integer types
          ptr = FFI::MemoryPointer.new(:int32, value.size)
          ptr.write_array_of_int32(value.map(&:to_i))
          ret = LibHTS.bam_aux_update_array(@record.struct, key, type.ord, value.size, ptr)
        when "f"
          # Float type
          ptr = FFI::MemoryPointer.new(:float, value.size)
          ptr.write_array_of_float(value.map(&:to_f))
          ret = LibHTS.bam_aux_update_array(@record.struct, key, type.ord, value.size, ptr)
        else
          raise ArgumentError, "Invalid array type: #{type}"
        end

        raise "Failed to update array tag '#{key}': errno #{FFI.errno}" if ret < 0

        value
      end

      # Delete an auxiliary tag
      # For compatibility with HTS.cr.
      # @param key [String] tag name (2 characters)
      # @return [Boolean] true if tag was deleted, false if tag was not found
      def delete(key)
        aux_ptr = LibHTS.bam_aux_get(@record.struct, key)
        return false if aux_ptr.null?

        ret = LibHTS.bam_aux_del(@record.struct, aux_ptr)
        raise "Failed to delete tag '#{key}': errno #{FFI.errno}" if ret < 0

        true
      end

      # Check if a tag exists
      # For compatibility with HTS.cr.
      # @param key [String] tag name (2 characters)
      # @return [Boolean] true if tag exists
      def key?(key)
        aux_ptr = LibHTS.bam_aux_get(@record.struct, key)
        !aux_ptr.null?
      end

      alias include? key?

      def first
        aux_ptr = first_pointer
        return nil if aux_ptr.null?

        get_ruby_aux(aux_ptr)
      end

      def each
        return enum_for(__method__) unless block_given?

        aux_ptr = first_pointer
        return nil if aux_ptr.null?

        loop do
          yield get_ruby_aux(aux_ptr)
          aux_ptr = LibHTS.bam_aux_next(@record.struct, aux_ptr)
          break if aux_ptr.null?
        end
      end

      def to_h
        h = {}
        aux_ptr = first_pointer
        return h if aux_ptr.null?

        loop do
          key = FFI::Pointer.new(aux_ptr.address - 2).read_string(2)
          h[key] = get_ruby_aux(aux_ptr)
          aux_ptr = LibHTS.bam_aux_next(@record.struct, aux_ptr)
          break if aux_ptr.null?
        end
        h
      end

      private

      def first_pointer
        LibHTS.bam_aux_first(@record.struct)
      end

      def get_ruby_aux(aux_ptr, type = nil)
        type = type ? type.to_s : aux_ptr.read_string(1)

        # A (character), B (general array),
        # f (real number), H (hexadecimal array),
        # i (integer), or Z (string).

        case type
        when "i", "I", "c", "C", "s", "S"
          LibHTS.bam_aux2i(aux_ptr)
        when "f", "d"
          LibHTS.bam_aux2f(aux_ptr)
        when "Z", "H"
          LibHTS.bam_aux2Z(aux_ptr)
        when "A" # char
          LibHTS.bam_aux2A(aux_ptr).chr
        when "B" # array
          t2 = aux_ptr.read_string(2)[1] # just a little less efficient
          l = LibHTS.bam_auxB_len(aux_ptr)
          case t2
          when "c", "C", "s", "S", "i", "I"
            # FIXME : Not efficient.
            Array.new(l) { |i| LibHTS.bam_auxB2i(aux_ptr, i) }
          when "f", "d"
            # FIXME : Not efficient.
            Array.new(l) { |i| LibHTS.bam_auxB2f(aux_ptr, i) }
          else
            raise NotImplementedError, "type: #{type} #{t2}"
          end
        else
          raise NotImplementedError, "type: #{type}"
        end
      end
    end
  end
end
