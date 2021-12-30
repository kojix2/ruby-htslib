# frozen_string_literal: true

module HTS
  class Bcf
    class Header
      def initialize(h)
        @h = h
      end

      def struct
        @h
      end

      def to_ptr
        @h.to_ptr
      end

      def to_s
        kstr = LibHTS::KString.new
        raise "Failed to get header string" unless LibHTS.bcf_hdr_format(@h, 0, kstr)

        kstr[:s]
      end
    end
  end
end
