# frozen_string_literal: true

module HTS
  class Bam < Hts
    # High-level mpileup iterator over multiple BAM/CRAM inputs
    class Mpileup
      include Enumerable

      # Usage:
      #   HTS::Bam::Mpileup.open([bam1, bam2], region: "chr1:1-100") do |mpl|
      #     mpl.each { |cols| ... }
      #   end
      def self.open(*args, **kw)
        m = new(*args, **kw)
        return m unless block_given?

        begin
          yield m
        ensure
          m.close
        end
        m
      end

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
        @iters       = []
        @data_blocks = [] # per-input packed pointers kept alive

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

        # Build per-input packed pointer blocks so C passes them back to the callback.
        # Layout per input: [0] hts_fp (htsFile*), [1] hdr_struct (bam_hdr_t*), [2] itr (hts_itr_t* or NULL)
        ptr_size = FFI.type_size(:pointer)
        data_array = FFI::MemoryPointer.new(:pointer, n)
        @bams.each_with_index do |bam, i|
          hts_fp     = bam.instance_variable_get(:@hts_file)
          hdr_struct = bam.header.struct
          itr        = @iters[i]
          block = FFI::MemoryPointer.new(:pointer, 3)
          block.put_pointer(0 * ptr_size, hts_fp)
          block.put_pointer(1 * ptr_size, hdr_struct)
          block.put_pointer(2 * ptr_size, itr && !itr.null? ? itr : FFI::Pointer::NULL)
          @data_blocks << block
          data_array.put_pointer(i * ptr_size, block)
        end
        # Keep the array of per-input blocks alive while the C side holds on to them
        @data_array = data_array

        @cb = FFI::Function.new(:int, %i[pointer pointer]) do |data, b|
          # Unpack pointers from the per-input block
          hts_fp     = data.get_pointer(0 * ptr_size)
          hdr_struct = data.get_pointer(1 * ptr_size)
          itr        = data.get_pointer(2 * ptr_size)
          if itr && !itr.null?
            r = HTS::LibHTS.sam_itr_next(hts_fp, itr, b)
            if r >= 0
              0
            else
              (r == -1 ? -1 : -2)
            end
          else
            r = HTS::LibHTS.sam_read1(hts_fp, hdr_struct, b)
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
        plp1_size = HTS::LibHTS::BamPileup1.size
        headers   = @bams.map(&:header)

        while HTS::LibHTS.bam_mplp64_auto(@iter, tid_ptr, pos_ptr, n_ptr, plp_ptr) > 0
          tid = tid_ptr.read_int
          pos = pos_ptr.read_long_long

          counts = n_ptr.read_array_of_int(n)
          plp_arr = plp_ptr.read_array_of_pointer(n)

          cols = Array.new(n)
          i = 0
          while i < n
            c = counts[i]
            if c <= 0 || plp_arr[i].null?
              cols[i] = HTS::Bam::Pileup::PileupColumn.new(tid: tid, pos: pos, alignments: [])
            else
              base_ptr = plp_arr[i]
              aligns = Array.new(c)
              j = 0
              while j < c
                e_ptr = base_ptr + (j * plp1_size)
                entry = HTS::LibHTS::BamPileup1.new(e_ptr)
                aligns[j] = HTS::Bam::Pileup::PileupRecord.new(entry, headers[i])
                j += 1
              end
              cols[i] = HTS::Bam::Pileup::PileupColumn.new(tid: tid, pos: pos, alignments: aligns)
            end
            i += 1
          end

          yield cols
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
        # Keep references to callback and data blocks to prevent GC
        @_keepalive = [@cb, @data_array, *@data_blocks]
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
