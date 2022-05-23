# frozen_string_literal: true

module HTS
  module LibHTS
    # constants
    BAM_CMATCH     = 0
    BAM_CINS       = 1
    BAM_CDEL       = 2
    BAM_CREF_SKIP  = 3
    BAM_CSOFT_CLIP = 4
    BAM_CHARD_CLIP = 5
    BAM_CPAD       = 6
    BAM_CEQUAL     = 7
    BAM_CDIFF      = 8
    BAM_CBACK      = 9

    BAM_CIGAR_STR = "MIDNSHP=XB"
    BAM_CIGAR_SHIFT = 4
    BAM_CIGAR_MASK  = 0xf
    BAM_CIGAR_TYPE  = 0x3C1A7

    # macros
    class << self
      def bam_cigar_op(c)
        c & BAM_CIGAR_MASK
      end

      def bam_cigar_oplen(c)
        c >> BAM_CIGAR_SHIFT
      end

      def bam_cigar_opchr(c)
        ("#{BAM_CIGAR_STR}??????")[bam_cigar_op(c)]
      end

      def bam_cigar_gen(l, o)
        l << BAM_CIGAR_SHIFT | o
      end

      def bam_cigar_type(o)
        BAM_CIGAR_TYPE >> (o << 1) & 3
      end
    end

    BAM_FPAIRED        =    1
    BAM_FPROPER_PAIR   =    2
    BAM_FUNMAP         =    4
    BAM_FMUNMAP        =    8
    BAM_FREVERSE       =   16
    BAM_FMREVERSE      =   32
    BAM_FREAD1         =   64
    BAM_FREAD2         =  128
    BAM_FSECONDARY     =  256
    BAM_FQCFAIL        =  512
    BAM_FDUP           = 1024
    BAM_FSUPPLEMENTARY = 2048

    # macros
    # function-like macros
    class << self
      def bam_is_rev(b)
        b[:core][:flag] & BAM_FREVERSE != 0
      end

      def bam_is_mrev(b)
        b[:core][:flag] & BAM_FMREVERSE != 0
      end

      def bam_get_qname(b)
        b[:data]
      end

      def bam_get_cigar(b)
        b[:data] + b[:core][:l_qname]
      end

      def bam_get_seq(b)
        b[:data] + (b[:core][:n_cigar] << 2) + b[:core][:l_qname]
      end

      def bam_get_qual(b)
        b[:data] + (b[:core][:n_cigar] << 2) + b[:core][:l_qname] + ((b[:core][:l_qseq] + 1) >> 1)
      end

      def bam_get_aux(b)
        b[:data] + (b[:core][:n_cigar] << 2) + b[:core][:l_qname] + ((b[:core][:l_qseq] + 1) >> 1) + b[:core][:l_qseq]
      end

      def bam_get_l_aux(b)
        b[:l_data] - (b[:core][:n_cigar] << 2) - b[:core][:l_qname] - b[:core][:l_qseq] - ((b[:core][:l_qseq] + 1) >> 1)
      end

      def bam_seqi(s, i)
        s[(i) >> 1].read_uint8 >> ((~i & 1) << 2) & 0xf
      end

      # def bam_set_seqi(s, i, b)
    end
  end
end
