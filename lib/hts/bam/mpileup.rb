# frozen_string_literal: true

module HTS
  class Bam < Hts
    # High-level mpileup iterator over multiple BAM/CRAM inputs
    class Mpileup
      include Enumerable

      # Normalize inputs to HTS::Bam instances
      # Accepts array of HTS::Bam or filenames (String)
      def initialize(inputs, region: nil, beg: nil, end_: nil, maxcnt: nil, overlaps: false)
        raise ArgumentError, "inputs must be non-empty" if inputs.nil? || inputs.empty?

        @owned_bams = [] # Bams we opened here; will be closed on close
        @bams = inputs.map do |x|
          case x
          when HTS::Bam
            x
          when String
            b = HTS::Bam.open(x)
            @owned_bams << b
            b
          else
            raise ArgumentError, "Unsupported input type: #{x.class}"
          end
        end

        n = @bams.length
        @state_map = {}
        @handles   = []
        @iters     = []

        # Prepare optional region iterators for each input
        @bams.each_with_index do |bam, i|
          itr = nil
          if region && beg.nil? && end_.nil?
            raise "Index required for region mpileup" unless bam.index_loaded?

            itr = HTS::LibHTS.sam_itr_querys(bam.instance_variable_get(:@idx), bam.header.struct, region)
            raise "Failed to query region on input ##{i}: #{region}" if itr.null?
          elsif region && beg && end_
            raise "Index required for region mpileup" unless bam.index_loaded?

            tid = bam.header.get_tid(region)
            itr = HTS::LibHTS.sam_itr_queryi(bam.instance_variable_get(:@idx), tid, beg, end_)
            raise "Failed to query region on input ##{i}: #{region} #{beg} #{end_}" if itr.null?
          elsif beg || end_
            raise ArgumentError, "beg and end_ must be specified together"
          end
          @iters << itr
        end

        # Build per-input handle pointers so C passes them back to the callback
        data_array = FFI::MemoryPointer.new(:pointer, n)
        @bams.each_with_index do |bam, i|
          handle = FFI::MemoryPointer.new(:char, 1) # unique address token
          @handles << handle
          @state_map[handle.address] = { bam:, itr: @iters[i] }
          data_array.put_pointer(i * FFI.type_size(:pointer), handle)
        end
        # Keep the array of per-input handles alive while the C side holds on to them
        @data_array = data_array

        @cb = FFI::Function.new(:int, %i[pointer pointer]) do |data, b|
          st = @state_map[data.address]
          bam = st[:bam]
          itr = st[:itr]
          if itr && !itr.null?
            slen = HTS::LibHTS.sam_itr_next(bam.instance_variable_get(:@hts_file), itr, b)
            if slen > 0
              0
            elsif slen == -1
              -1
            else
              -2
            end
          else
            r = HTS::LibHTS.sam_read1(bam.instance_variable_get(:@hts_file), bam.header.struct, b)
            r == -1 ? -1 : 0
          end
        end

        @iter = HTS::LibHTS.bam_mplp_init(n, @cb, @data_array)
        raise "bam_mplp_init failed" if @iter.null?

        HTS::LibHTS.bam_mplp_set_maxcnt(@iter, maxcnt) if maxcnt
        return unless overlaps

        rc = HTS::LibHTS.bam_mplp_init_overlaps(@iter)
        raise "bam_mplp_init_overlaps failed" if rc < 0
      end

      # Yields an array of Pileup::PileupColumn (one per input) for each position
      def each
        return to_enum(__method__) unless block_given?

        n = @bams.length
        tid_ptr = FFI::MemoryPointer.new(:int)
        pos_ptr = FFI::MemoryPointer.new(:long_long)
        n_ptr   = FFI::MemoryPointer.new(:int, n)
        plp_ptr = FFI::MemoryPointer.new(:pointer, n)

        begin
          while HTS::LibHTS.bam_mplp64_auto(@iter, tid_ptr, pos_ptr, n_ptr, plp_ptr) > 0
            tid = tid_ptr.read_int
            pos = pos_ptr.read_long_long

            counts = n_ptr.read_array_of_int(n)
            plp_arr = plp_ptr.read_array_of_pointer(n)

            cols = Array.new(n) do |i|
              c = counts[i]
              if c <= 0 || plp_arr[i].null?
                HTS::Bam::Pileup::PileupColumn.new(tid: tid, pos: pos, alignments: [])
              else
                base_ptr = plp_arr[i]
                size = HTS::LibHTS::BamPileup1.size
                aligns = c.times.map do |j|
                  e_ptr = base_ptr + (j * size)
                  entry = HTS::LibHTS::BamPileup1.new(e_ptr)
                  HTS::Bam::Pileup::PileupRecord.new(entry, @bams[i].header)
                end
                HTS::Bam::Pileup::PileupColumn.new(tid: tid, pos: pos, alignments: aligns)
              end
            end

            yield cols
          end
        ensure
          close
        end

        self
      end

      def close
        if @iter && !@iter.null?
          HTS::LibHTS.bam_mplp_destroy(@iter)
          @iter = FFI::Pointer::NULL
        end
        @iters.each do |itr|
          HTS::LibHTS.hts_itr_destroy(itr) if itr && !itr.null?
        end
        @iters.clear
        # Keep references to callback and handles to prevent GC
        @_keepalive = [@cb, *@handles]
        # Close owned bams opened by this object
        @owned_bams.each do |b|
          b.close
        rescue StandardError
        end
        @owned_bams.clear
      end
    end
  end
end
