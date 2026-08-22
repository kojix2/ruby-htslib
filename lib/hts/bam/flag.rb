# frozen_string_literal: true

# Based on hts-nim
# https://github.com/brentp/hts-nim/blob/master/src/hts/bam/flag.nim

module HTS
  class Bam < Hts
    # SAM flags
    class Flag
      def initialize(flag_value)
        raise TypeError unless flag_value.is_a? Integer

        @value = flag_value
      end

      attr_accessor :value

      PAIRED = 1
      PROPER_PAIR = 2
      UNMAPPED = 4
      MATE_UNMAPPED = 8
      REVERSE = 16
      MATE_REVERSE = 32
      READ1 = 64
      READ2 = 128
      SECONDARY = 256
      QCFAIL = 512
      DUPLICATE = 1024
      SUPPLEMENTARY = 2048

      UNMAP = UNMAPPED
      MUNMAP = MATE_UNMAPPED
      DUP = DUPLICATE

      TABLE = { paired?: PAIRED, proper_pair?: PROPER_PAIR, unmapped?: UNMAPPED,
                mate_unmapped?: MATE_UNMAPPED, reverse?: REVERSE,
                mate_reverse?: MATE_REVERSE, read1?: READ1, read2?: READ2,
                secondary?: SECONDARY, qcfail?: QCFAIL, duplicate?: DUPLICATE,
                supplementary?: SUPPLEMENTARY }.freeze

      # @!macro [attach] generate_flag_methods
      #   @!method $1
      #   @return [Boolean]
      def self.generate(name)
        define_method(name) do
          (@value & TABLE[name]) != 0
        end
      end
      private_class_method :generate

      generate :paired?
      generate :proper_pair?
      generate :unmapped?
      generate :mate_unmapped?
      generate :reverse?
      generate :mate_reverse?
      generate :read1?
      generate :read2?
      generate :secondary?
      generate :qcfail?
      generate :duplicate?
      generate :supplementary?

      def has_flag?(f)
        (@value & f) != 0
      end

      def &(other)
        self.class.new(@value & other.to_i)
      end

      def |(other)
        self.class.new(@value | other.to_i)
      end

      def ^(other)
        self.class.new(@value ^ other.to_i)
      end

      def ~
        self.class.new((~@value) & 0x0fff)
      end

      def <<(f)
        self.class.new(@value << f.to_i)
      end

      def >>(other)
        self.class.new(@value >> other.to_i)
      end

      def to_i
        @value
      end

      def to_s
        Native.bam_flag_string(@value)
      end
    end
  end
end
