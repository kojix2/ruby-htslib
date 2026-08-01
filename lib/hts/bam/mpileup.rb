# frozen_string_literal: true

module HTS
  class Bam < Hts
    class Mpileup
      include Enumerable

      class DepthView
        include Enumerable
        attr_reader :length
        alias size length
        def initialize = reset([])

        def reset(values)
          @values = values
          @length = values.length
          self
        end

        def [](index)
          index = Integer(index)
          index += @length if index.negative?
          raise IndexError, "depth index #{index} outside of view" unless index.between?(0, @length - 1)

          @values[index]
        end

        def each(&block)
          return to_enum(__method__) unless block_given?

          @values.each(&block)
          self
        end
      end

      class ColumnsView
        include Enumerable
        attr_reader :tid, :pos, :length
        alias size length
        def initialize = @column_view = Pileup::BorrowedColumnView.new

        def reset(tid, pos, rows)
          @tid = tid
          @pos = pos
          @rows = rows
          @length = rows.length
          self
        end

        def each
          return to_enum(__method__) unless block_given?

          @rows.each_with_index { |entries, index| yield index, @column_view.reset(entries, @tid, @pos) }
          self
        end
      end

      def self.open(*args, **keywords)
        mpileup = new(*args, **keywords)
        return mpileup unless block_given?

        begin
          yield mpileup
        ensure
          mpileup.close
        end
        mpileup
      end

      def initialize(inputs, region: nil, beg: nil, end_: nil, maxcnt: nil, overlaps: false)
        raise ArgumentError, "inputs must be non-empty" if inputs.nil? || inputs.empty?

        @owned_bams = []
        @bams = inputs.map do |input|
          case input
          when HTS::Bam then input
          when String
            HTS::Bam.open(input).tap { |bam| @owned_bams << bam }
          else raise ArgumentError, "Unsupported input type: #{input.class}"
          end
        end
        files = @bams.map { |bam| bam.__send__(:native_handle) }
        headers = @bams.map { |bam| bam.header.__send__(:native_handle) }
        @native = Native::MpileupHandle.open(files, headers, region, beg, end_, maxcnt, overlaps)
        @closed = false
      end

      def each
        return to_enum(__method__) unless block_given?

        headers = @bams.map(&:header)
        each_column_raw do |tid, pos, _depths, rows_by_input, _|
          columns = rows_by_input.each_with_index.map do |rows, index|
            alignments = rows.map { |row| Pileup::PileupRecord.new(row, headers[index]) }
            Pileup::PileupColumn.new(tid:, pos:, alignments:)
          end
          yield columns
        end
        self
      end

      def each_depth
        return to_enum(__method__) unless block_given?

        view = DepthView.new
        each_column_raw { |tid, pos, depths, _, _| yield tid, pos, view.reset(depths) }
        self
      end

      def each_view
        return to_enum(__method__) unless block_given?

        view = ColumnsView.new
        each_column_raw { |tid, pos, _, rows, _| yield view.reset(tid, pos, rows) }
        self
      end

      def each_entry_raw
        return to_enum(__method__) unless block_given?

        each_column_raw do |tid, pos, _, rows_by_input, _|
          rows_by_input.each_with_index do |rows, input_index|
            rows.each { |row| yield input_index, tid, pos, row[1], row[7], row[8], row[9] }
          end
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

        counts = Array.new(@bams.length) { Array.new(Pileup::BASE_COUNT_FIELDS.length, 0) }
        each_column_raw do |tid, pos, _, rows_by_input, _|
          rows_by_input.each_with_index do |rows, input_index|
            aggregate_counts(rows, counts[input_index], min_base_quality, min_mapping_quality)
          end
          yield tid, pos, counts
        end
        self
      end

      # The fourth value is an Array of opaque native-entry rows. It remains
      # borrowed until the next iteration.
      def each_column_raw
        return to_enum(__method__) unless block_given?

        while (column = @native.next)
          tid, pos, depths, rows = column
          yield tid, pos, depths, rows, @bams.length
        end
        self
      end

      def reset
        @native.reset
        self
      end

      def close
        return if @closed

        @native.close
        @owned_bams.each(&:close)
        @owned_bams.clear
        @closed = true
        nil
      end

      private

      def aggregate_counts(rows, counts, min_base_quality, min_mapping_quality)
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
      end
    end
  end
end
