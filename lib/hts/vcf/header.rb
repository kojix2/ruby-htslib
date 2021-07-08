# frozen_string_literal: true

module HTS
  class VCF
    class Header
      attr_reader :h

      def initialize(h)
        @h = h
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
