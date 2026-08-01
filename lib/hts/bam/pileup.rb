# frozen_string_literal: true

require_relative "../native"

module HTS
  class Bam < Hts
    class Pileup
      include Enumerable
      BASE_COUNT_FIELDS = %i[depth a c g t n forward reverse deletion insertion].freeze

      def self.open(*args, **keywords)
        pileup = new(*args, **keywords)
        return pileup unless block_given?

        begin
          yield pileup
        ensure
          pileup.close
        end
        pileup
      end

      PileupColumn = Struct.new(:tid, :pos, :alignments, keyword_init: true) do
        def depth = alignments.length
      end

      class PileupRecord
        def initialize(values, header)
          @values = values
          @header = header
        end

        def record = (@record ||= HTS::Bam::Record.new(@header, @values[0]))
        def query_position = @values[1]
        def indel = @values[2]
        def del? = @values[3]
        def head? = @values[4]
        def tail? = @values[5]
        def refskip? = @values[6]
      end

      class BorrowedEntryView
        def reset(values, tid, pos)
          @values = values
          @tid = tid
          @pos = pos
          self
        end
        attr_reader :tid, :pos

        def query_position = @values[1]
        def indel = @values[2]
        def del? = @values[3]
        def refskip? = @values[6]
        def flag = @values[7]
        def base_code = @values[8]
        def quality = @values[9]
      end

      class BorrowedColumnView
        include Enumerable
        attr_reader :tid, :pos, :depth

        def initialize = @entry_view = BorrowedEntryView.new

        def reset(rows, tid, pos)
          @rows = rows
          @tid = tid
          @pos = pos
          @depth = rows.length
          self
        end

        def each
          return to_enum(__method__) unless block_given?

          @rows.each { |row| yield @entry_view.reset(row, @tid, @pos) }
          self
        end
      end

      def initialize(bam, region: nil, beg: nil, end_: nil, maxcnt: nil)
        raise ArgumentError, "beg and end_ must be specified together" if beg.nil? != end_.nil?
        raise ArgumentError, "region is required when beg/end_ are specified" if !beg.nil? && region.nil?

        @bam = bam
        @header = bam.header
        @native = Native::PileupHandle.open(
          bam.__send__(:native_handle), @header.__send__(:native_handle), region, beg, end_, maxcnt
        )
      end

      def each
        return to_enum(__method__) unless block_given?

        each_raw_column do |tid, pos, rows|
          alignments = rows.map { |row| PileupRecord.new(row, @header) }
          yield PileupColumn.new(tid:, pos:, alignments:)
        end
        self
      end

      def each_depth
        return to_enum(__method__) unless block_given?

        each_raw_column { |tid, pos, rows| yield tid, pos, rows.length }
        self
      end

      def each_view
        return to_enum(__method__) unless block_given?

        view = BorrowedColumnView.new
        each_raw_column { |tid, pos, rows| yield view.reset(rows, tid, pos) }
        self
      end

      def each_entry_raw
        return to_enum(__method__) unless block_given?

        each_raw_column do |tid, pos, rows|
          rows.each { |row| yield tid, pos, row[1], row[7], row[8], row[9] }
        end
        self
      end

      def each_base_counts(min_base_quality: 0, min_mapping_quality: 0)
        return to_enum(__method__, min_base_quality:, min_mapping_quality:) unless block_given?

        min_base_quality = Integer(min_base_quality)
        min_mapping_quality = Integer(min_mapping_quality)
        if min_base_quality.negative? || min_mapping_quality.negative?
          raise ArgumentError,
                "quality thresholds must be non-negative"
        end

        counts = Array.new(BASE_COUNT_FIELDS.length, 0)
        each_raw_column do |tid, pos, rows|
          counts.fill(0)
          rows.each do |row|
            next if row[6] || row[10] < min_mapping_quality

            if row[3] || row[1].negative?
              counts[8] += 1
            else
              next if row[9] < min_base_quality

              counts[{ 1 => 1, 2 => 2, 4 => 3, 8 => 4 }.fetch(row[8], 5)] += 1
            end
            counts[0] += 1
            counts[(row[7] & 16).zero? ? 6 : 7] += 1
            counts[9] += 1 if row[2].positive?
          end
          yield tid, pos, counts
        end
        self
      end

      def reset = @native.reset
      def close = @native&.close

      private

      def next_raw = @native.next

      def each_raw_column
        while (column = next_raw)
          yield(*column)
        end
      end
    end
  end
end
