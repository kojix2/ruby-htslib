# frozen_string_literal: true

# Based on hts-nim
# https://github.com/brentp/hts-nim/blob/master/src/hts/bam/flag.nim

module HTS
  class Bam
    class Flag
      def initialize(flag_value)
        raise TypeError unless flag_value.is_a? Integer
        @value = flag_value
      end

      attr_accessor :value

      # BAM_FPAIRED        =    1
      # BAM_FPROPER_PAIR   =    2
      # BAM_FUNMAP         =    4
      # BAM_FMUNMAP        =    8
      # BAM_FREVERSE       =   16
      # BAM_FMREVERSE      =   32
      # BAM_FREAD1         =   64
      # BAM_FREAD2         =  128
      # BAM_FSECONDARY     =  256
      # BAM_FQCFAIL        =  512
      # BAM_FDUP           = 1024
      # BAM_FSUPPLEMENTARY = 2048

      # TODO: Enabling bitwise operations
      # hts-nim
      # proc `and`*(f: Flag, o: uint16): uint16 {. borrow, inline .}
      # proc `and`*(f: Flag, o: Flag): uint16 {. borrow, inline .}
      # proc `or`*(f: Flag, o: uint16): uint16 {. borrow .}
      # proc `or`*(o: uint16, f: Flag): uint16 {. borrow .}
      # proc `==`*(f: Flag, o: Flag): bool {. borrow, inline .}
      # proc `==`*(f: Flag, o: uint16): bool {. borrow, inline .}
      # proc `==`*(o: uint16, f: Flag): bool {. borrow, inline .}

      def paired?
        has_flag? LibHTS::BAM_FPAIRED
      end

      def proper_pair?
        has_flag? LibHTS::BAM_FPROPER_PAIR
      end

      def unmapped?
        has_flag? LibHTS::BAM_FUNMAP
      end

      def mate_unmapped?
        has_flag? LibHTS::BAM_FMUNMAP
      end

      def reverse?
        has_flag? LibHTS::BAM_FREVERSE
      end

      def mate_reverse?
        has_flag? LibHTS::BAM_FMREVERSE
      end

      def read1?
        has_flag? LibHTS::BAM_FREAD1
      end

      def read2?
        has_flag? LibHTS::BAM_FREAD2
      end

      def secondary?
        has_flag? LibHTS::BAM_FSECONDARY
      end

      def qcfail?
        has_flag? LibHTS::BAM_FQCFAIL
      end

      def dup?
        has_flag? LibHTS::BAM_FDUP
      end

      def supplementary?
        has_flag? LibHTS::BAM_FSUPPLEMENTARY
      end

      def has_flag?(o)
        @value[o] != 0
      end
    end
  end
end
