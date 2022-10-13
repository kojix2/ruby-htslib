# frozen_string_literal: true

require_relative "header/record"

module HTS
  class Bcf < Hts
    # A class for working with VCF records.
    class Header
      def initialize(arg = nil)
        case arg
        when LibHTS::HtsFile
          @bcf_hdr = LibHTS.bcf_hdr_read(arg)
        when LibHTS::BcfHdr
          @bcf_hdr = arg
        when nil
          @bcf_hdr = LibHTS.bcf_hdr_init("w")
        else
          raise TypeError, "Invalid argument"
        end
      end

      def struct
        @bcf_hdr
      end

      def to_ptr
        @bcf_hdr.to_ptr
      end

      def get_version
        LibHTS.bcf_hdr_get_version(@bcf_hdr)
      end

      def set_version(version)
        LibHTS.bcf_hdr_set_version(@bcf_hdr, version)
      end

      def nsamples
        LibHTS.bcf_hdr_nsamples(@bcf_hdr)
      end

      def samples
        # bcf_hdr_id2name is macro function
        @bcf_hdr[:samples]
          .read_array_of_pointer(nsamples)
          .map(&:read_string)
      end

      def add_sample(sample, sync: true)
        LibHTS.bcf_hdr_add_sample(@bcf_hdr, sample)
        self.sync if sync
      end

      def sync
        LibHTS.bcf_hdr_sync(@bcf_hdr)
      end

      def to_s
        kstr = LibHTS::KString.new
        raise "Failed to get header string" unless LibHTS.bcf_hdr_format(@bcf_hdr, 0, kstr)

        kstr[:s]
      end

      private

      def initialize_copy(orig)
        @bcf_hdr = LibHTS.bcf_hdr_dup(orig.struct)
      end
    end
  end
end
