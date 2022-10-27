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

      # TODO: Enabling bitwise operations?

      TABLE = { paired?: LibHTS::BAM_FPAIRED,
                proper_pair?: LibHTS::BAM_FPROPER_PAIR,
                unmapped?: LibHTS::BAM_FUNMAP,
                mate_unmapped?: LibHTS::BAM_FMUNMAP,
                reverse?: LibHTS::BAM_FREVERSE,
                mate_reverse?: LibHTS::BAM_FMREVERSE,
                read1?: LibHTS::BAM_FREAD1,
                read2?: LibHTS::BAM_FREAD2,
                secondary?: LibHTS::BAM_FSECONDARY,
                qcfail?: LibHTS::BAM_FQCFAIL,
                duplicate?: LibHTS::BAM_FDUP,
                supplementary?: LibHTS::BAM_FSUPPLEMENTARY }.freeze

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

      def to_i
        @value
      end

      def to_s
        LibHTS.bam_flag2str(@value)
        # "0x#{format('%x', @value)}\t#{@value}\t#{LibHTS.bam_flag2str(@value)}"
      end
    end
  end
end
