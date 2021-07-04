# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Bam
    class Record
      SEQ_NT16_STR = '=ACMGRSVTWYHKDBN'

      def initialize(bam1_t, bam_hdr_t)
        @b = bam1_t
        @h = bam_hdr_t
      end

      # def initialize_copy
      #   super
      # end

      def self.rom_sam_str; end

      def tags; end

      # Read (query) name.
      def qname
        FFI.bam_get_qname(@b).read_string
      end

      # Set (query) name.
      # def qname=(name)
      #   raise 'Not Implemented'
      # end

      # returns the tid of the record or -1 if not mapped.
      def tid
        @b[:core][:tid]
      end

      # returns the tid of the mate or -1 if not mapped.
      def mate_tid
        @b[:core][:mtid]
      end

      # returns 0-based start position.
      def start
        @b[:core][:pos]
      end

      # returns end position of the read.
      def stop
        FFI.bam_endpos @b
      end

      # returns 0-based mate position
      def mate_start
        @b[:core][:mpos]
      end
      alias_method :mate_pos, :mate_start

      # returns the chromosome or '' if not mapped.
      def chrom
        tid = @b[:core][:tid]
        return '' if tid == -1

        FFI.sam_hdr_tid2name(@h, tid)
      end

      # returns the chromosome of the mate or '' if not mapped.
      def mate_chrom
        tid = @b[:core][:mtid]
        return '' if tid == -1

        FFI.sam_hdr_tid2name(@h, tid)
      end

      def strand
        FFI.bam_is_rev(@b) ? '-' : '+'
      end

      # def start=(v)
      #   raise 'Not Implemented'
      # end

      # insert size
      def isize
        @b[:core][:isize]
      end

      # mapping quality
      def mapping_quality
        @b[:core][:qual]
      end

      # returns a `Cigar` object.
      def cigar
        Cigar.new(FFI.bam_get_cigar(@b), @b[:core][:n_cigar])
      end

      def qlen
        FFI.bam_cigar2qlen(
          @b[:core][:n_cigar],
          FFI.bam_get_cigar(@b)
        )
      end

      def rlen
        FFI.bam_cigar2rlen(
          @b[:core][:n_cigar],
          FFI.bam_get_cigar(@b)
        )
      end

      # return the read sequence
      def sequence
        r = FFI.bam_get_seq(@b)
        seq = String.new
        (@b[:core][:l_qseq]).times do |i|
          seq << SEQ_NT16_STR[FFI.bam_seqi(r, i)]
        end
        seq
      end

      # return only the base of the requested index "i" of the query sequence.
      def base_at(n)
        n += @b[:core][:l_qseq] if n < 0
        return '.' if (n >= @b[:core][:l_qseq]) || (n < 0) # eg. base_at(-1000)

        r = FFI.bam_get_seq(@b)
        SEQ_NT16_STR[FFI.bam_seqi(r, n)]
      end

      # return the base qualities
      def base_qualities
        q_ptr = FFI.bam_get_qual(@b)
        q_ptr.read_array_of_uint8(@b[:core][:l_qseq])
      end

      # return only the base quality of the requested index "i" of the query sequence.
      def base_quality_at(n)
        n += @b[:core][:l_qseq] if n < 0 
        return 0 if (n >= @b[:core][:l_qseq]) || (n < 0) # eg. base_quality_at(-1000)

        q_ptr = FFI.bam_get_qual(@b)
        q_ptr.get_uint8(n)
      end

      def flag_str
        FFI.bam_flag2str(flag)
      end

      # returns a `Flag` object.
      def flag
        @b[:core][:flag]
      end

      # TODO:
      # def eql?
      # def hash
    end
  end
end
