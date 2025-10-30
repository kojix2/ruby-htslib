# frozen_string_literal: true

module HTS
  class Bam < Hts
    # High-level pileup iterator for a single SAM/BAM/CRAM
    class Pileup
      include Enumerable

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
        end

        # Lightweight read-only view over the underlying bam1_t without taking ownership.
        def record
          @record_view ||= ReadView.new(@entry[:b])
        end

        class ReadView
          def initialize(bam1_ptr)
            # Accept either FFI::Pointer or FFI::Struct (Managed/Unmanaged); store as raw pointer
            @bam1_ptr = bam1_ptr.is_a?(FFI::Pointer) ? bam1_ptr : bam1_ptr.to_ptr
          end

          def base(i)
            view = HTS::LibHTS::Bam1View.new(@bam1_ptr)
            seq_ptr = HTS::LibHTS.bam_get_seq(view)
            HTS::Bam::Record::SEQ_NT16_STR[HTS::LibHTS.bam_seqi(seq_ptr, i)]
          end
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

        # Build the auto callback for bam_plp_init
        @cb = FFI::Function.new(:int, %i[pointer pointer]) do |_data, b|
          if @itr && !@itr.null?
            slen = HTS::LibHTS.sam_itr_next(@bam.instance_variable_get(:@hts_file), @itr, b)
            if slen > 0
              0
            elsif slen == -1
              -1
            else
              -2
            end
          else
            r = HTS::LibHTS.sam_read1(@bam.instance_variable_get(:@hts_file), @header.struct, b)
            r == -1 ? -1 : 0
          end
        end

        @plp = HTS::LibHTS.bam_plp_init(@cb, nil)
        raise "bam_plp_init failed" if @plp.null?

        HTS::LibHTS.bam_plp_set_maxcnt(@plp, maxcnt) if maxcnt
      end

      def each
        return to_enum(__method__) unless block_given?

        tid_ptr = FFI::MemoryPointer.new(:int)
        pos_ptr = FFI::MemoryPointer.new(:long_long) # hts_pos_t
        n_ptr   = FFI::MemoryPointer.new(:int)

        begin
          while (base_ptr = HTS::LibHTS.bam_plp64_auto(@plp, tid_ptr, pos_ptr, n_ptr)) && !base_ptr.null?
            tid = tid_ptr.read_int
            pos = pos_ptr.read_long_long
            n   = n_ptr.read_int

            # Construct alignment entries
            alignments = if n.zero?
                           []
                         else
                           size = HTS::LibHTS::BamPileup1.size
                           n.times.map do |i|
                             e_ptr = base_ptr + (i * size)
                             entry = HTS::LibHTS::BamPileup1.new(e_ptr)
                             PileupRecord.new(entry, @header)
                           end
                         end

            yield PileupColumn.new(tid:, pos:, alignments:)
          end
        ensure
          close
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
    end
  end
end
