# frozen_string_literal: true

module HTS
  class Bam < Hts
    class Aux
      def initialize(record)
        @record = record
      end

      def get(key, type = nil)
        aux = LibHTS.bam_aux_get(@record.struct, key)
        return nil if aux.null?

        type ||= aux.read_string(1)

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

      def [](key)
        get(key)
      end
    end
  end
end
