# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  # A cigar object usually created from `Alignment`.
  class Bam
    class Alignment
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

      # returns the chromosome of the mate or '' if not mapped.
      def mate_chrom
        tid = @b[:core][:mtid]
        return '' if tid == -1

        FFI.sam_hdr_tid2name(@h, tid)
      end

      # returns the tid of the mate or -1 if not mapped.
      def mate_tid
        @b[:core][:mtid]
      end

      # returns the tid of the alignment or -1 if not mapped.
      def tid
        @b[:core][:tid]
      end

      # mate position
      def mate_pos
        mpos = @b[:core][:mpos]
        return if mpos == -1

        mpos
      end

      def rname
        tid = @b[:core][:tid]
        return if tid == -1

        FFI.sam_hdr_tid2name(@h, tid)
      end

      def strand
        FFI.bam_is_rev(@b) ? '-' : '+'
      end

      def pos
        pos = @b[:core][:pos]
        return if pos == -1

        pos
      end

      # def pos=(v)
      #   raise 'Not Implemented'
      # end

      def isize
        @b[:core][:isize]
      end

      def mapping_quality
        @b[:core][:qual]
      end

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

      def sequence
        seq_nt16_str = "=ACMGRSVTWYHKDBN"
        r = FFI.bam_get_seq(@b)
        Array.new(@b[:core][:l_qseq]) do |i|
          seq_nt16_str[FFI.bam_seqi(r, i)]
        end.join
      end

      def base_at(n)
        n = n + @b[:core][:l_qseq] if n < 0
        seq_nt16_str = "=ACMGRSVTWYHKDBN"
        return '.' if n >= @b[:core][:l_qseq] or n < 0 # eg. base_at(-1000)
        r = FFI.bam_get_seq(@b)
        seq_nt16_str[FFI.bam_seqi(r, n)]
      end

      def base_qualities
        q_ptr = FFI.bam_get_qual(@b)
        q_ptr.read_array_of_uint8(@b[:core][:l_qseq])
      end

      def base_quality_at(n)
        n = n + @b[:core][:l_qseq] if n < 0 # eg. base_quality_at(-1000)
        return 0 if n >= @b[:core][:l_qseq] or n < 0
        q_ptr = FFI.bam_get_qual(@b)
        q_ptr.get_uint8(n)
      end

      def flag_str
        FFI.bam_flag2str(flag)
      end

      def flag
        @b[:core][:flag]
      end

      # TODO:
      # def eql?
      # def hash

    end
  end
end
