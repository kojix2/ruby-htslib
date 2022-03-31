# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Bam < Hts
    class Header
      def initialize(hts_file)
        @sam_hdr = LibHTS.sam_hdr_read(hts_file)
      end

      def struct
        @sam_hdr
      end

      def to_ptr
        @sam_hdr.to_ptr
      end

      def target_count
        @sam_hdr[:n_targets]
      end

      def target_names
        Array.new(target_count) do |i|
          LibHTS.sam_hdr_tid2name(@sam_hdr, i)
        end
      end

      def target_lengths
        Array.new(target_count) do |i|
          LibHTS.sam_hdr_tid2len(@sam_hdr, i)
        end
      end

      def to_s
        LibHTS.sam_hdr_str(@sam_hdr)
      end

      private

      def initialize_copy(orig)
        @sam_hdr = LibHTS.sam_hdr_dup(orig.struct)
      end
    end
  end
end
