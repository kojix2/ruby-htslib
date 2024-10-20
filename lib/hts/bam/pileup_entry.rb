module HTS
  class Bam
    class PileupEntry
      attr_reader :is_del, :is_refskip

      def initialize(pointer)
        @entry = LibHTS::BamPileup1.new(pointer)
      end

      def qpos
        @entry[:qpos]
      end

      def indel
        @entry[:indel]
      end

      def level
        @entry[:level]
      end

      def is_del?
        @entry[:is_del]
      end

      def i1_refskip?
        @entry[:is_refskip]
      end

      def base
        s = LibHTS.bam_get_seq(@entry[:b])
        Bam::Record::SEQ_NT16_STR[LibHTS.bam_seqi(s, qpos)]
      end

      def to_s
        # FIXME
        "Position: #{qpos}, Indel: #{indel}, Base: #{base}"
      end
    end
  end
end
