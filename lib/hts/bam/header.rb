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

      def seqs
        Array.new(@h[:n_targets]) do |i|
          @h[:target_name][i].read_string # FIXME
        end
      end

      def text
        @h[:text]
      end
    end
  end
end
