# frozen_string_literal: true

require_relative "header_record"

module HTS
  class Bam < Hts
    # A class for working with alignment header.
    class Header
      def initialize(arg = nil)
        case arg
        when LibHTS::HtsFile
          @sam_hdr = LibHTS.sam_hdr_read(arg)
        when LibHTS::SamHdr
          @sam_hdr = arg
        when nil
          @sam_hdr = LibHTS.sam_hdr_init
        else
          raise TypeError, "Invalid argument"
        end
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

      def target_len
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
