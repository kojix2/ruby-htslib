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
