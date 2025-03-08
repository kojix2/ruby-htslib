module HTS
  class Bam
    class PileupEntry
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
        @entry[:is_del] == 1
      end

      def is_refskip?
        @entry[:is_refskip] == 1
      end

      def base
        s = LibHTS.bam_get_seq(@entry[:b])
        Bam::Record::SEQ_NT16_STR[LibHTS.bam_seqi(s, qpos)]
      end

      def to_s
        "Position: #{qpos}, Indel: #{indel}, Level: #{level}, Base: #{base}, Is_del: #{is_del?}, Is_refskip: #{is_refskip?}"
      end
    end
  end
end
