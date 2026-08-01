# frozen_string_literal: true

require_relative "../native"

module HTS
  class Bam < Hts
    # High-level mpileup iterator over multiple BAM/CRAM inputs
    class Mpileup
      include Enumerable

      # A borrowed, reusable view over the per-input depths at one position.
      # Do not retain it after the iterator advances; call #to_a for an owning
      # snapshot when the values must outlive the callback.
      class DepthView
        include Enumerable

        def initialize
          @pointer = nil
          @length = 0
        end

        attr_reader :length
        alias size length

        def [](index)
          index = Integer(index)
          index += @length if index.negative?
          raise ::IndexError, "depth index #{index} outside of view" unless index.between?(0, @length - 1)

          @pointer.get_int32(index * FFI.type_size(:int32))
        end

        def each
          return to_enum(__method__) unless block_given?

          i = 0
          while i < @length
            yield @pointer.get_int32(i * FFI.type_size(:int32))
            i += 1
          end
          self
        end

        def reset(pointer, length)
          @pointer = pointer
          @length = length
          self
        end
      end

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
        @data_entries = {}

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
        # Keep the Ruby FFI structs in @data_entries to avoid rebuilding wrappers
        # in the per-record callback.
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
          @data_entries[block.address] = [hts_fp, hdr_struct, itr && !itr.null? ? itr : nil]
          data_array.put_pointer(i * ptr_size, block)
        end
        # Keep the array of per-input blocks alive while the C side holds on to them
        @data_array = data_array

        @cb = FFI::Function.new(:int, %i[pointer pointer]) do |data, b|
          hts_fp, hdr_struct, itr = @data_entries.fetch(data.address)
          # HTSlib contract: return same as sam_itr_next/sam_read1 (>= 0 on success, -1 on EOF, < -1 on error)
          if itr
            HTS::LibHTS.sam_itr_next(hts_fp, itr, b)
          else
            HTS::LibHTS.sam_read1(hts_fp, hdr_struct, b)
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
        plp1_size = HTS::LibHTS::BamPileup1.size
        headers   = @bams.map(&:header)

        each_column_raw do |tid, pos, n_ptr, plp_ptr, _input_count|
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

      # Yield one position and a borrowed reusable view of its per-input
      # depths, without creating column or pileup-record objects.
      def each_depth
        return to_enum(__method__) unless block_given?

        view = DepthView.new
        each_column_raw do |tid, pos, counts_pointer, _pileups_pointer, input_count|
          yield tid, pos, view.reset(counts_pointer, input_count)
        end
        self
      end

      # Yield primitive pileup entry values without constructing columns or
      # duplicating Bam::Record instances. base is a BAM nt16 integer code, or
      # nil for a deletion/reference skip.
      def each_entry_raw
        return to_enum(__method__) unless block_given?

        entry_size = HTS::LibHTS::BamPileup1.size
        pointer_size = FFI.type_size(:pointer)
        int_size = FFI.type_size(:int)

        each_column_raw do |tid, pos, counts_pointer, pileups_pointer, input_count|
          input_index = 0
          while input_index < input_count
            depth = counts_pointer.get_int32(input_index * int_size)
            base_pointer = pileups_pointer.get_pointer(input_index * pointer_size)
            entry_index = 0
            while entry_index < depth
              entry = HTS::LibHTS::BamPileup1.new(base_pointer + entry_index * entry_size)
              bam = HTS::LibHTS::Bam1View.new(entry[:b])
              qpos = entry[:qpos]
              flag = bam[:core][:flag]

              if entry[:is_del] == 1 || entry[:is_refskip] == 1 || qpos.negative?
                base = nil
                quality = nil
              else
                base = HTS::LibHTS.bam_seqi(HTS::LibHTS.bam_get_seq(bam), qpos)
                quality = HTS::LibHTS.bam_get_qual(bam).get_uint8(qpos)
              end
              yield input_index, tid, pos, qpos, flag, base, quality
              entry_index += 1
            end
            input_index += 1
          end
        end
        self
      end

      # Yield reused base-count arrays for all inputs at each position. Each
      # inner array uses Pileup::BASE_COUNT_FIELDS order. Duplicate the arrays
      # before retaining them beyond the callback.
      def each_base_counts(min_base_quality: 0, min_mapping_quality: 0)
        return to_enum(__method__, min_base_quality:, min_mapping_quality:) unless block_given?

        min_base_quality = Integer(min_base_quality)
        min_mapping_quality = Integer(min_mapping_quality)
        raise ArgumentError, "quality thresholds must be non-negative" if min_base_quality.negative? || min_mapping_quality.negative?

        input_count = @bams.length
        counts = Array.new(input_count) { Array.new(Pileup::BASE_COUNT_FIELDS.length, 0) }
        int_size = FFI.type_size(:int)
        pointer_size = FFI.type_size(:pointer)

        each_column_raw do |tid, pos, depths_pointer, pileups_pointer, _|
          input_index = 0
          while input_index < input_count
            depth = depths_pointer.get_int32(input_index * int_size)
            pileup_pointer = pileups_pointer.get_pointer(input_index * pointer_size)
            if depth.zero? || pileup_pointer.null?
              counts[input_index].fill(0)
            else
              HTS::Native.pileup_base_counts(
                pileup_pointer.address, depth, min_base_quality,
                min_mapping_quality, counts[input_index]
              )
            end
            input_index += 1
          end
          yield tid, pos, counts
        end
        self
      end

      # Lowest-level column iterator. The count and pileup pointers are
      # borrowed from HTSlib and remain valid only until iteration advances.
      def each_column_raw
        return to_enum(__method__) unless block_given?

        input_count = @bams.length
        tid_pointer = FFI::MemoryPointer.new(:int)
        pos_pointer = FFI::MemoryPointer.new(:long_long)
        counts_pointer = FFI::MemoryPointer.new(:int, input_count)
        pileups_pointer = FFI::MemoryPointer.new(:pointer, input_count)

        loop do
          result = HTS::LibHTS.bam_mplp64_auto(
            @iter, tid_pointer, pos_pointer, counts_pointer, pileups_pointer
          )
          break if result.zero?
          raise "HTSlib mpileup error (bam_mplp64_auto)" if result.negative?

          yield tid_pointer.read_int, pos_pointer.read_long_long,
                counts_pointer, pileups_pointer, input_count
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
        @_keepalive = [@cb, @data_array, @data_entries, *@data_blocks]
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
