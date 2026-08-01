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

    unless respond_to?(:bam_sequence)
      def bam_sequence(address)
        bam = LibHTS::Bam1View.new(FFI::Pointer.new(Integer(address)))
        pointer = LibHTS.bam_get_seq(bam)
        length = bam[:core][:l_qseq]
        result = String.new(capacity: length)
        length.times { |index| result << HTS::Bam::Record::SEQ_NT16_STR[LibHTS.bam_seqi(pointer, index)] }
        result
      end
    end

    unless respond_to?(:bam_quality_string)
      def bam_quality_string(address)
        bam = LibHTS::Bam1View.new(FFI::Pointer.new(Integer(address)))
        length = bam[:core][:l_qseq]
        return "" if length.zero?

        pointer = LibHTS.bam_get_qual(bam)
        return "*" if pointer.get_uint8(0) == 255

        result = String.new(capacity: length, encoding: Encoding::BINARY)
        length.times { |index| result << (pointer.get_uint8(index) + 33) }
        result
      end
    end

    unless respond_to?(:aux_b_array)
      def aux_b_array(address)
        pointer = FFI::Pointer.new(Integer(address))
        raise TypeError, "AUX value is not a B array" unless pointer.get_uint8(0) == "B".ord

        subtype = pointer.get_uint8(1).chr
        length = pointer.get_uint32(2)
        payload = pointer + 6
        case subtype
        when "c" then payload.get_array_of_int8(0, length)
        when "C" then payload.get_array_of_uint8(0, length)
        when "s" then payload.get_array_of_int16(0, length)
        when "S" then payload.get_array_of_uint16(0, length)
        when "i" then payload.get_array_of_int32(0, length)
        when "I" then payload.get_array_of_uint32(0, length)
        when "f" then payload.get_array_of_float32(0, length)
        else raise NotImplementedError, "AUX B-array subtype: #{subtype}"
        end
      end
    end

    unless respond_to?(:selected_fields)
      def selected_fields(line, columns)
        requested = {}
        columns.each_with_index { |column, result_index| (requested[column] ||= []) << result_index }
        result = Array.new(columns.length)
        max_column = columns.max
        field_start = 0
        column = 0
        byte_index = 0
        while byte_index <= line.bytesize && column <= max_column
          if byte_index == line.bytesize || line.getbyte(byte_index) == 9
            if (indices = requested[column])
              value = line.byteslice(field_start, byte_index - field_start)
              indices.each { |index| result[index] = value }
            end
            column += 1
            field_start = byte_index + 1
          end
          byte_index += 1
        end
        result
      end
    end

    unless respond_to?(:bam_filter_records)
      def bam_filter_records(records, required_flags, excluded_flags, min_mapq, tid, beg_pos, end_pos)
        records.select do |record|
          flags = record.flag_value
          (flags & required_flags) == required_flags &&
            (flags & excluded_flags).zero? && record.mapq >= min_mapq &&
            (tid.nil? || record.tid == tid) &&
            (beg_pos.nil? || record.endpos > beg_pos) &&
            (end_pos.nil? || record.pos < end_pos)
        end
      end
    end

    unless respond_to?(:bcf_filter_records)
      def bcf_filter_records(records, rid, beg_pos, end_pos, min_qual, filter_id)
        records.select do |record|
          (rid.nil? || record.rid == rid) &&
            (beg_pos.nil? || record.endpos > beg_pos) &&
            (end_pos.nil? || record.pos < end_pos) &&
            (min_qual.nil? || (!record.qual.nan? && record.qual >= min_qual)) &&
            (filter_id.nil? || record.filter_id?(filter_id))
        end
      end
    end

    unless respond_to?(:format_float_values)
      def format_float_values(address, count, sample_count, scalar)
        pointer = FFI::Pointer.new(Integer(address))
        count = Integer(count)
        sample_count = Integer(sample_count)
        raise ArgumentError, "invalid FORMAT sample layout" if sample_count <= 0 || (count % sample_count) != 0

        width = count.div(sample_count)
        Array.new(sample_count) do |sample|
          offset = sample * width
          if scalar
            word = pointer.get_uint32(offset * 4)
            if word == LibHTS.bcf_float_missing || word == LibHTS.bcf_float_vector_end
              nil
            else
              pointer.get_float32(offset * 4)
            end
          else
            row = []
            width.times do |index|
              byte_offset = (offset + index) * 4
              word = pointer.get_uint32(byte_offset)
              break if word == LibHTS.bcf_float_vector_end

              row << (word == LibHTS.bcf_float_missing ? nil : pointer.get_float32(byte_offset))
            end
            row
          end
        end
      end
    end

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
