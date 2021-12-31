# frozen_string_literal: true

module HTS
  class Bcf
    class Header
      def initialize(bcf_hdr)
        @bcf_hdr = bcf_hdr
      end

      def struct
        @bcf_hdr
      end

      def to_ptr
        @bcf_hdr.to_ptr
      end

      def to_s
        kstr = LibHTS::KString.new
        raise "Failed to get header string" unless LibHTS.bcf_hdr_format(@bcf_hdr, 0, kstr)

        kstr[:s]
      end
    end
  end
end
