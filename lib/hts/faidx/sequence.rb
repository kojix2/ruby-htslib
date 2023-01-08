require_relative "../faidx"

module HTS
  class Faidx
    class Sequence
      attr_reader :name, :faidx

      def initialize(faidx, name)
        raise unless faidx.names.include?(name)

        @faidx = faidx
        @name = name
      end

      def length
        faidx.seq_len(name)
      end

      def seq(start = nil, stop = nil)
        faidx.seq(name, start, stop)
      end

      alias size length
    end
  end
end
