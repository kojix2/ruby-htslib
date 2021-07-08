# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Bam
    class Record
      SEQ_NT16_STR = "=ACMGRSVTWYHKDBN"

      def initialize(bam1_t, bam_hdr_t)
        @b1 = bam1_t
        @h = bam_hdr_t
      end

      # def initialize_copy
      #   super
      # end

      def self.rom_sam_str; end

      def tags; end

      # returns the query name.
      def qname
        LibHTS.bam_get_qname(@b1).read_string
      end

      # Set (query) name.
      # def qname=(name)
      #   raise 'Not Implemented'
      # end

      # returns the tid of the record or -1 if not mapped.
      def tid
        @b1[:core][:tid]
      end

      # returns the tid of the mate or -1 if not mapped.
      def mate_tid
        @b1[:core][:mtid]
      end

      # returns 0-based start position.
      def start
        @b1[:core][:pos]
      end

      # returns end position of the read.
      def stop
        LibHTS.bam_endpos @b1
      end

      # returns 0-based mate position
      def mate_start
        @b1[:core][:mpos]
      end
      alias mate_pos mate_start

      # returns the chromosome or '' if not mapped.
      def chrom
        tid = @b1[:core][:tid]
        return "" if tid == -1

        LibHTS.sam_hdr_tid2name(@h, tid)
      end

      # returns the chromosome of the mate or '' if not mapped.
      def mate_chrom
        tid = @b1[:core][:mtid]
        return "" if tid == -1

        LibHTS.sam_hdr_tid2name(@h, tid)
      end

      def strand
        LibHTS.bam_is_rev(@b1) ? "-" : "+"
      end

      # def start=(v)
      #   raise 'Not Implemented'
      # end

      # insert size
      def isize
        @b1[:core][:isize]
      end

      # mapping quality
      def mapping_quality
        @b1[:core][:qual]
      end

      # returns a `Cigar` object.
      def cigar
        Cigar.new(LibHTS.bam_get_cigar(@b1), @b1[:core][:n_cigar])
      end

      def qlen
        LibHTS.bam_cigar2qlen(
          @b1[:core][:n_cigar],
          LibHTS.bam_get_cigar(@b1)
        )
      end

      def rlen
        LibHTS.bam_cigar2rlen(
          @b1[:core][:n_cigar],
          LibHTS.bam_get_cigar(@b1)
        )
      end

      # return the read sequence
      def sequence
        r = LibHTS.bam_get_seq(@b1)
        seq = String.new
        (@b1[:core][:l_qseq]).times do |i|
          seq << SEQ_NT16_STR[LibHTS.bam_seqi(r, i)]
        end
        seq
      end

      # return only the base of the requested index "i" of the query sequence.
      def base_at(n)
        n += @b1[:core][:l_qseq] if n < 0
        return "." if (n >= @b1[:core][:l_qseq]) || (n < 0) # eg. base_at(-1000)

        r = LibHTS.bam_get_seq(@b1)
        SEQ_NT16_STR[LibHTS.bam_seqi(r, n)]
      end

      # return the base qualities
      def base_qualities
        q_ptr = LibHTS.bam_get_qual(@b1)
        q_ptr.read_array_of_uint8(@b1[:core][:l_qseq])
      end

      # return only the base quality of the requested index "i" of the query sequence.
      def base_quality_at(n)
        n += @b1[:core][:l_qseq] if n < 0
        return 0 if (n >= @b1[:core][:l_qseq]) || (n < 0) # eg. base_quality_at(-1000)

        q_ptr = LibHTS.bam_get_qual(@b1)
        q_ptr.get_uint8(n)
      end

      def flag_str
        LibHTS.bam_flag2str(@b1[:core][:flag])
      end

      # returns a `Flag` object.
      def flag
        Flag.new(@b1[:core][:flag])
      end

      # TODO:
      # def eql?
      # def hash
    end
  end
end
