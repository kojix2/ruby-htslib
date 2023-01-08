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
      alias size length

      def seq(start = nil, stop = nil)
        faidx.seq(name, start, stop)
      end

      def [](arg)
        case arg
        when Integer
          if arg >= 0
            start = arg
            stop = arg
          else
            start = length + arg
            stop = length + arg
          end
        when Range
          arg = Range.new(arg.begin, arg.end + length, arg.exclude_end?) if arg.end&.<(0)
          arg = Range.new(arg.begin + length, arg.end, arg.exclude_end?) if arg.begin&.<(0)
          if arg.begin.nil?
            if arg.end.nil?
              start = nil
              stop = nil
            else
              start = 0
              stop = arg.exclude_end? ? arg.end - 1 : arg.end
            end
          elsif arg.end.nil?
            # always include the first base
            start = arg.begin
            stop = length - 1
          else
            start = arg.begin
            stop = arg.exclude_end? ? arg.end - 1 : arg.end
          end
        else
          raise ArgumentError
        end
        seq(start, stop)
      end
    end
  end
end
