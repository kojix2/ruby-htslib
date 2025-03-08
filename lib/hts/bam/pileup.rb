module HTS
  class Bam
    class Pileup
      include Enumerable

      def initialize(bam)
        @bam = bam
        # typedef int (*bam_plp_auto_f)(void *data, bam1_t *b);
        f = FFI::Function.new(:int, [:pointer, :pointer], blocking: true) do |data, b|
          0
        end
        pt = FFI::MemoryPointer.new(:pointer)
        @iterator = LibHTS.bam_plp_init(f, pt)
        raise "Failed to initialize pileup" if @iterator.null?
      end

      def each(&block)
        return enum_for(:each) unless block_given?

        @bam.each do |record|
          raise "Failed to push BAM record" if LibHTS.bam_plp_push(@iterator, record.struct) < 0

          while (entries = fetch_next_pileup)
            entries.each(&block)
          end
        end
        # Signal the end of the BAM stream by pushing a NULL record
        LibHTS.bam_plp_push(@iterator, nil)
      end

      private

      def fetch_next_pileup
        tid_ptr = FFI::MemoryPointer.new(:int)
        pos_ptr = FFI::MemoryPointer.new(:int)
        n_plp_ptr = FFI::MemoryPointer.new(:int)

        entries = LibHTS.bam_plp_next(@iterator, tid_ptr, pos_ptr, n_plp_ptr)
        return nil if entries.null?

        n_plp = n_plp_ptr.read_int
        Array.new(n_plp) { |i| PileupEntry.new(entries.pointer + i * LibHTS::BamPileup1.size) }
      end
    end
  end
end
