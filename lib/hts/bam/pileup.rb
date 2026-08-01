# frozen_string_literal: true

require_relative "../native"

module HTS
  class Bam < Hts
    # High-level pileup iterator for a single SAM/BAM/CRAM
    class Pileup
      include Enumerable

      BASE_COUNT_FIELDS = %i[depth a c g t n forward reverse deletion insertion].freeze

      # Usage:
      #   HTS::Bam::Pileup.open(bam, region: "chr1:1-100") do |pl|
      #     pl.each { |col| ... }
      #   end
      def self.open(*args, **kw)
        pu = new(*args, **kw)
        return pu unless block_given?

        begin
          yield pu
        ensure
          pu.close
        end
        pu
      end

      # A column at a reference position with pileup alignments
      PileupColumn = Struct.new(:tid, :pos, :alignments, keyword_init: true) do
        def depth
          alignments.length
        end
      end

      # A wrapper of one bam_pileup1_t entry
      class PileupRecord
        def initialize(entry, header)
          @entry  = entry
          @header = header
          @record = nil
        end

        # Return Bam::Record. On the first call, duplicate the underlying bam1_t (bam_dup1)
        # so the record becomes safe to keep beyond the current pileup step. Subsequent calls
        # return the cached Bam::Record instance.
        # NOTE: Without duplication, bam1_t memory may be reused by HTSlib on the next step.
        def record
          return @record if @record

          # Normalize to a raw pointer and duplicate to obtain owned memory.
          b_ptr = @entry[:b].is_a?(FFI::Pointer) ? @entry[:b] : @entry[:b].to_ptr
          dup_ptr = HTS::LibHTS.bam_dup1(b_ptr)
          raise "bam_dup1 failed" if dup_ptr.null?

          # Build a Bam::Record backed by the duplicated bam1_t.
          @record = HTS::Bam::Record.new(@header, dup_ptr)
        end

        def query_position
          @entry[:qpos]
        end

        def indel
          @entry[:indel]
        end

        def del?
          @entry[:is_del] == 1
        end

        def head?
          @entry[:is_head] == 1
        end

        def tail?
          @entry[:is_tail] == 1
        end

        def refskip?
          @entry[:is_refskip] == 1
        end
      end

      # Borrowed, reusable object view over one pileup entry.
      class BorrowedEntryView
        def reset(pointer, tid, pos)
          @entry = HTS::LibHTS::BamPileup1.new(pointer)
          @tid = tid
          @pos = pos
          self
        end

        attr_reader :tid, :pos

        def query_position = @entry[:qpos]
        def indel = @entry[:indel]
        def del? = @entry[:is_del] == 1
        def refskip? = @entry[:is_refskip] == 1

        def flag
          HTS::LibHTS::Bam1View.new(@entry[:b])[:core][:flag]
        end

        def base_code
          return nil if del? || refskip? || query_position.negative?

          bam = HTS::LibHTS::Bam1View.new(@entry[:b])
          HTS::LibHTS.bam_seqi(HTS::LibHTS.bam_get_seq(bam), query_position)
        end

        def quality
          return nil if del? || refskip? || query_position.negative?

          bam = HTS::LibHTS::Bam1View.new(@entry[:b])
          HTS::LibHTS.bam_get_qual(bam).get_uint8(query_position)
        end
      end

      # Borrowed column view. Both this object and its entry view are reused.
      class BorrowedColumnView
        include Enumerable

        def initialize
          @entry_view = BorrowedEntryView.new
        end

        attr_reader :tid, :pos, :depth

        def reset(pointer, tid, pos, depth)
          @pointer = pointer
          @tid = tid
          @pos = pos
          @depth = depth
          self
        end

        def each
          return to_enum(__method__) unless block_given?

          entry_size = HTS::LibHTS::BamPileup1.size
          @depth.times do |index|
            yield @entry_view.reset(@pointer + index * entry_size, @tid, @pos)
          end
          self
        end
      end

      # Create a Pileup iterator
      # @param bam [HTS::Bam]
      # @param region [String, nil] Optional region string (requires index)
      # @param beg [Integer, nil] Optional begin when using tid/beg/end form
      # @param end_ [Integer, nil] Optional end when using tid/beg/end form
      # @param maxcnt [Integer, nil] Max per-position depth (capped)
      def initialize(bam, region: nil, beg: nil, end_: nil, maxcnt: nil)
        @bam    = bam
        @header = bam.header
        @itr    = nil
        @cb     = nil
        @plp    = nil

        # Optional region iterator
        if region && beg.nil? && end_.nil?
          raise "Index file is required to use region pileup." unless bam.index_loaded?

          @itr = HTS::LibHTS.sam_itr_querys(bam.instance_variable_get(:@idx), @header.struct, region)
          raise "Failed to query region: #{region}" if @itr.null?
        elsif region && beg && end_
          raise "Index file is required to use region pileup." unless bam.index_loaded?

          tid = @header.get_tid(region)
          @itr = HTS::LibHTS.sam_itr_queryi(bam.instance_variable_get(:@idx), tid, beg, end_)
          raise "Failed to query region: #{region} #{beg} #{end_}" if @itr.null?
        elsif beg || end_
          raise ArgumentError, "beg and end_ must be specified together"
        end

        # Build the auto callback for bam_plp_init (micro-optimized)
        # - Hoist ivar/constant lookups out of the callback to reduce per-call overhead.
        # - Specialize callbacks to avoid branching in the hot path.
        hts_fp     = @bam.instance_variable_get(:@hts_file)
        hdr_struct = @header.struct
        itr_local  = @itr

        @cb = if itr_local && !itr_local.null?
                FFI::Function.new(:int, %i[pointer pointer]) do |_data, b|
                  # HTSlib contract: return same as sam_itr_next (>= 0 on success, -1 on EOF, < -1 on error)
                  HTS::LibHTS.sam_itr_next(hts_fp, itr_local, b)
                end
              else
                FFI::Function.new(:int, %i[pointer pointer]) do |_data, b|
                  # HTSlib contract: return same as sam_read1 (>= 0 on success, -1 on EOF, < -1 on error)
                  HTS::LibHTS.sam_read1(hts_fp, hdr_struct, b)
                end
              end

        @plp = HTS::LibHTS.bam_plp_init(@cb, nil)
        raise "bam_plp_init failed" if @plp.null?

        HTS::LibHTS.bam_plp_set_maxcnt(@plp, maxcnt) if maxcnt
      end

      def each
        return to_enum(__method__) unless block_given?

        plp1_size    = HTS::LibHTS::BamPileup1.size
        header_local = @header

        each_raw_column do |base_ptr, tid, pos, n|
          # Construct alignment entries with minimal allocations
          if n.zero?
            alignments = []
          else
            alignments = Array.new(n)
            i = 0
            while i < n
              e_ptr = base_ptr + (i * plp1_size)
              entry = HTS::LibHTS::BamPileup1.new(e_ptr)
              alignments[i] = PileupRecord.new(entry, header_local)
              i += 1
            end
          end

          yield PileupColumn.new(tid: tid, pos: pos, alignments: alignments)
        end

        self
      end

      # Yield one primitive depth result per genomic position without creating
      # PileupColumn or PileupRecord objects.
      def each_depth
        return to_enum(__method__) unless block_given?

        each_raw_column { |_base_ptr, tid, pos, depth| yield tid, pos, depth }
        self
      end

      # Yield a borrowed column object that is reset for every position.
      def each_view
        return to_enum(__method__) unless block_given?

        view = BorrowedColumnView.new
        each_raw_column do |pointer, tid, pos, depth|
          yield view.reset(pointer, tid, pos, depth)
        end
        self
      end

      # Yield primitive pileup entry values. base is the BAM nt16 integer code,
      # or nil for deletions/reference skips. No Bam::Record is duplicated.
      def each_entry_raw
        return to_enum(__method__) unless block_given?

        entry_size = HTS::LibHTS::BamPileup1.size
        each_raw_column do |base_ptr, tid, pos, depth|
          depth.times do |index|
            entry = HTS::LibHTS::BamPileup1.new(base_ptr + index * entry_size)
            bam_pointer = entry[:b]
            bam = HTS::LibHTS::Bam1View.new(bam_pointer)
            qpos = entry[:qpos]
            flag = bam[:core][:flag]

            if entry[:is_del] == 1 || entry[:is_refskip] == 1 || qpos.negative?
              base = nil
              quality = nil
            else
              base = HTS::LibHTS.bam_seqi(HTS::LibHTS.bam_get_seq(bam), qpos)
              quality = HTS::LibHTS.bam_get_qual(bam).get_uint8(qpos)
            end
            yield tid, pos, qpos, flag, base, quality
          end
        end
        self
      end

      # Yield one reused count array per genomic position. The fields are, in
      # order: depth, A, C, G, T, N, forward, reverse, deletion, insertion.
      # Call counts.dup when retaining a result beyond the callback.
      def each_base_counts(min_base_quality: 0, min_mapping_quality: 0)
        return to_enum(__method__, min_base_quality:, min_mapping_quality:) unless block_given?

        min_base_quality = Integer(min_base_quality)
        min_mapping_quality = Integer(min_mapping_quality)
        raise ArgumentError, "quality thresholds must be non-negative" if min_base_quality.negative? || min_mapping_quality.negative?

        counts = Array.new(BASE_COUNT_FIELDS.length, 0)
        each_raw_column do |base_pointer, tid, pos, depth|
          HTS::Native.pileup_base_counts(
            base_pointer.address, depth, min_base_quality, min_mapping_quality, counts
          )
          yield tid, pos, counts
        end
        self
      end

      def reset
        HTS::LibHTS.bam_plp_reset(@plp) if @plp && !@plp.null?
      end

      def close
        if @plp && !@plp.null?
          HTS::LibHTS.bam_plp_destroy(@plp)
          @plp = FFI::Pointer::NULL
        end
        if @itr && !@itr.null?
          HTS::LibHTS.hts_itr_destroy(@itr)
          @itr = FFI::Pointer::NULL
        end
        # Keep @cb referenced by instance to avoid GC during iteration.
        @cb
      end

      private

      def each_raw_column
        tid_ptr = FFI::MemoryPointer.new(:int)
        pos_ptr = FFI::MemoryPointer.new(:long_long)
        count_ptr = FFI::MemoryPointer.new(:int)

        loop do
          base_ptr = HTS::LibHTS.bam_plp64_auto(@plp, tid_ptr, pos_ptr, count_ptr)
          if base_ptr.null?
            count = count_ptr.read_int
            raise "HTSlib pileup error (bam_plp64_auto)" if count.negative?

            break
          end

          yield base_ptr, tid_ptr.read_int, pos_ptr.read_long_long, count_ptr.read_int
        end
      end
    end
  end
end
