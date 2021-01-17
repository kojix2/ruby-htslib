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

      def rnext
        tid = @b[:core][:mtid]
        return if tid == -1

        FFI.sam_hdr_tid2name(@h, tid)
      end

      def pnext
        @b[:core][:mpos]
      end

      def rname
        tid = @b[:core][:tid]
        return if tid == -1

        FFI.sam_hdr_tid2name(@h, tid)
      end

      def strand
        FFI.bam_is_rev(@b) ? '-' : '+'
      end

      def base_qualities
        q_ptr = FFI.bam_get_qual(@b)
        q_ptr.read_array_of_uint8(@b[:core][:l_qseq])
      end

      def pos
        @b[:core][:pos]
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

      def seqs; end

      def flag_str; end

      def flag; end

      # def eql?
      # def hash

      def to_s; end
    end
  end
end
