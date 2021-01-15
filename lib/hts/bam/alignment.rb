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

      def initialize_copy
        super
      end

      def self.rom_sam_str; end

      def tags; end

      # Read (query) name.
      def qname
        HTS::FFI.bam_get_qname(@b).read_string
      end

      # Set (query) name.
      def qname=(name); end

      def rnext
        @b[:core][:mpos]
      end

      def pnext; end

      def rname; end

      def strand; end

      def base_qualities; end

      def pos; end

      def pos=; end

      def isize; end

      def mapping_quality; end

      def cigar; end

      def qlen; end

      def rlen; end

      def seqs; end

      def flag_str; end

      def flag; end

      # def eql?
      # def hash

      def to_s; end
    end
  end
end
