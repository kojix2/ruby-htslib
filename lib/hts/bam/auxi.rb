# frozen_string_literal: true

# Q. Why is the file name auxi.rb and not aux.rb?
#
# A. This is for compatibility with Windows.
# In Windows, aux is a reserved word
# You cannot create a file named aux. Eww!

module HTS
  class Bam < Hts
    # Auxiliary record data
    #
    # @noge Aux is a View object.
    # The result of the alignment is assigned to the bam1 structure.
    # Ruby's Aux class references a part of it. There is no one-to-one
    # correspondence between C structures and Ruby's Aux class.
    class Aux
      attr_reader :record

      def initialize(record)
        @record = record
      end

      # @note Why is this method named "get" instead of "fetch"?
      # This is for compatibility with the Crystal language
      # which provides methods like `get_int`, `get_float`, etc.
      # I think they are better than `fetch_int`` and `fetch_float`.
      def get(key, type = nil)
        aux = LibHTS.bam_aux_get(@record.struct, key)
        return nil if aux.null?

        type = type ? type.to_s : aux.read_string(1)

        # A (character), B (general array),
        # f (real number), H (hexadecimal array),
        # i (integer), or Z (string).

        case type
        when "i", "I", "c", "C", "s", "S"
          LibHTS.bam_aux2i(aux)
        when "f", "d"
          LibHTS.bam_aux2f(aux)
        when "Z", "H"
          LibHTS.bam_aux2Z(aux)
        when "A" # char
          LibHTS.bam_aux2A(aux).chr
        else
          raise NotImplementedError, "type: #{t}"
        end
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
    end
  end
end
