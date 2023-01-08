require_relative "../faidx"

module HTS
  class Faidx
    class Sequence
      attr_reader :name, :faidx

      def initialize(faidx, name)
        raise unless faidx.has_key?(name)

        @faidx = faidx
        @name = name
      end

      def length
        faidx.seq_len(name)
      end

      def seq(start = nil, stop = nil)
        faidx.seq(name, start, stop)
      end

      def [](arg)
        case arg
        when Integer
          faidx.seq(name, arg, arg)
        when Range
          if arg.begin.nil?
            if arg.end.nil?
              start = nil
              stop = nil
            else
              start = 0
              stop = arg.max
            end
          elsif arg.end.nil?
            start = arg.min
            stop = length
          else
            start, stop = arg.minmax
          end
        else
          raise ArgumentError
        end
        seq(start, stop)
      end

      alias size length
    end
  end
end
