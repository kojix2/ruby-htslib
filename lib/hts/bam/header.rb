# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Bam
    class Header
      attr_reader :h

      def initialize(h)
        @h = h
      end

      # FIXME: better name?
      def seqs
        Array.new(@h[:n_targets]) do |i|
          HTS::FFI.sam_hdr_tid2name(@h, i)
        end
      end

      def text
        HTS::FFI.sam_hdr_str(@h)
      end
    end
  end
end
