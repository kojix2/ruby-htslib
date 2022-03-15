# frozen_string_literal: true

module HTS
  class Bcf
    class Header
      def initialize(hts_file)
        @bcf_hdr = LibHTS.bcf_hdr_read(hts_file)
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
