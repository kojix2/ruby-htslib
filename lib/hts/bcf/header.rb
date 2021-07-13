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

      # FIXME: better name?
      def seqs
        Array.new(@h[:n_targets]) do |i|
          LibHTS.sam_hdr_tid2name(@h, i)
        end
      end

      def text
        LibHTS.sam_hdr_str(@h)
      end
    end
  end
end
