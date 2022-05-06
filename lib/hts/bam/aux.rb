# frozen_string_literal: true

module HTS
  class Bam < Hts
    class Aux
      def initialize(record)
        @record = record
      end

      def get_int(key)
        get(key, :int)
      end

      def get_float(key)
        get(key, :float)
      end

      def get_string(key)
        get(key, :string)
      end

      def get_flag(key)
        get(key, :flag)
      end

      def get(key, _type = nil)
        aux = LibHTS.bam_aux_get(@record.struct, key)
        return nil if aux.null?

        t = aux.read_string(1)

        # A (character), B (general array),
        # f (real number), H (hexadecimal array),
        # i (integer), or Z (string).

        case t
        when "i", "I", "c", "C", "s", "S"
          LibHTS.bam_aux2i(aux)
        when "f", "d"
          LibHTS.bam_aux2f(aux)
        when "Z", "H"
          LibHTS.bam_aux2Z(aux)
        when "A" # char
          LibHTS.bam_aux2A(aux).chr
        end
      end
    end
  end
end
