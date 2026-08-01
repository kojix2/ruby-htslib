# frozen_string_literal: true

begin
  require "htslib_native_ext"
rescue LoadError
end

module HTS
  # Optional native batch operations, with portable Ruby fallbacks.
  module Native
    AVAILABLE = false unless const_defined?(:AVAILABLE, false)

    module_function

    unless respond_to?(:pileup_base_counts)
      # Fill result with depth/base/strand/indel counts for one pileup column.
      def pileup_base_counts(address, depth, min_base_quality, min_mapping_quality, result)
        result.fill(0)
        pointer = FFI::Pointer.new(Integer(address))
        entry_size = LibHTS::BamPileup1.size

        Integer(depth).times do |index|
          entry = LibHTS::BamPileup1.new(pointer + index * entry_size)
          next if entry[:is_refskip] == 1

          bam = LibHTS::Bam1View.new(entry[:b])
          next if bam[:core][:qual] < min_mapping_quality

          qpos = entry[:qpos]
          if entry[:is_del] == 1 || qpos.negative?
            result[8] += 1
          else
            quality = LibHTS.bam_get_qual(bam).get_uint8(qpos)
            next if quality < min_base_quality

            base = LibHTS.bam_seqi(LibHTS.bam_get_seq(bam), qpos)
            result[base_count_index(base)] += 1
          end

          result[0] += 1
          result[(bam[:core][:flag] & LibHTS::BAM_FREVERSE).zero? ? 6 : 7] += 1
          result[9] += 1 if entry[:indel].positive?
        end
        result
      end

      def base_count_index(base)
        case base
        when 1 then 1 # A
        when 2 then 2 # C
        when 4 then 3 # G
        when 8 then 4 # T
        else 5        # N and ambiguous codes
        end
      end
      private_class_method :base_count_index
    end
  end
end
