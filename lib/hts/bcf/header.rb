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
    end
  end
end
