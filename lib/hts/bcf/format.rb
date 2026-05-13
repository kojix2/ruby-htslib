# frozen_string_literal: true

module HTS
  class Bcf < Hts
    class Format
      def initialize(record)
        @record = record
      end

      # @note: Why is this method named "get" instead of "fetch"?
      # This is for compatibility with the Crystal language
      # which provides methods like `get_int`, `get_float`, etc.
      # I think they are better than `fetch_int`` and `fetch_float`.
      def get(key, type = nil)
        return get_raw(key, type) unless type.nil?

        return decode_genotypes if key == "GT"

        case header_format_type(key)
        when :int
          decode_integer_values(key)
        when :float
          decode_float_values(key)
        when :flag
          raise_unsupported_format_flag(key)
        when :string
          get_string_values(key)
        end
      end

      def get_raw(key, type = nil)
        # The GT FORMAT field is special in that it is marked as a string in the header,
        # but it is actually encoded as an integer.
        type = if type.nil?
                 key == "GT" ? :int : header_format_type(key)
               else
                 type.to_sym
               end

        case type
        when :int, :int32
          raise_unsupported_format_flag(key)
          get_numeric_values(key, LibHTS::BCF_HT_INT, "integer") { |dst, len| dst.read_array_of_int32(len) }
        when :float, :real
          raise_unsupported_format_flag(key)
          get_numeric_values(key, LibHTS::BCF_HT_REAL, "float") { |dst, len| dst.read_array_of_float(len) }
        when :flag
          raise_unsupported_format_flag(key)
        when :string, :str
          return decode_genotypes if key == "GT"

          raise_unsupported_format_flag(key)
          get_string_values(key)
        end
      end

      # For compatibility with HTS.cr.
      def get_int(key)
        get_raw(key, :int)
      end

      # For compatibility with HTS.cr.
      def get_float(key)
        get_raw(key, :float)
      end

      # For compatibility with HTS.cr.
      def get_flag(key)
        get_raw(key, :flag)
      end

      # For compatibility with HTS.cr.
      def get_string(key)
        get_raw(key, :string)
      end

      # For compatibility with HTS.cr.
      def get_genotypes
        get_numeric_values("GT", LibHTS::BCF_HT_INT, "genotype") { |dst, len| dst.read_array_of_int32(len) }
      end

      def [](key)
        get(key)
      end

      def update_int(key, values)
        raise UnsupportedFormatOperationError, "Use update_genotypes for GT" if key == "GT"

        ensure_expected_format_type!(key, :int, "integer")
        values = normalize_int_values(values)
        validate_numeric_sample_count!(key, values.size)

        ptr = FFI::MemoryPointer.new(:int32, values.size)
        ptr.write_array_of_int32(values)
        check_update_rc!(LibHTS.bcf_update_format_int32(@record.header.struct, @record.struct, key, ptr, values.size),
                         key)
      end

      def update_float(key, values)
        ensure_expected_format_type!(key, :float, "float")
        values = normalize_float_values(values)
        validate_numeric_sample_count!(key, values.size)

        ptr = FFI::MemoryPointer.new(:float, values.size)
        ptr.write_array_of_float(values)
        check_update_rc!(LibHTS.bcf_update_format_float(@record.header.struct, @record.struct, key, ptr, values.size),
                         key)
      end

      def update_string(key, values)
        raise UnsupportedFormatOperationError, "Use update_genotypes for GT" if key == "GT"

        ensure_expected_format_type!(key, :string, "string")
        values = normalize_string_values(values)
        validate_string_sample_count!(key, values.size)

        strings = values.map { |value| FFI::MemoryPointer.from_string(value) }
        ptr = FFI::MemoryPointer.new(:pointer, strings.size)
        ptr.write_array_of_pointer(strings)
        check_update_rc!(LibHTS.bcf_update_format_string(@record.header.struct, @record.struct, key, ptr, values.size),
                         key)
      end

      def update_genotypes(values)
        ensure_gt_defined!

        values = normalize_int_values(values)
        validate_numeric_sample_count!("GT", values.size)

        ptr = FFI::MemoryPointer.new(:int32, values.size)
        ptr.write_array_of_int32(values)
        check_update_rc!(LibHTS.bcf_update_genotypes(@record.header.struct, @record.struct, ptr, values.size), "GT")
      end

      def delete(key)
        return false if header_format_type(key).nil?
        return false unless format_present?(key)

        type = key == "GT" ? LibHTS::BCF_HT_INT : header_format_type_code(key)
        ret = LibHTS.bcf_update_format(@record.header.struct, @record.struct, key, FFI::Pointer::NULL, 0, type)
        raise FormatUpdateError, "Failed to delete FORMAT field '#{key}': #{ret}" if ret < 0

        true
      end

      def fields
        ids.map do |id|
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, id)
          num  = LibHTS.bcf_hdr_id2number(@record.header.struct, LibHTS::BCF_HL_FMT, id)
          type = LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_FMT, id)
          {
            name:,
            n: num,
            type: ht_type_to_sym(type),
            id:
          }
        end
      end

      def length
        @record.struct[:n_fmt]
      end

      def size
        length
      end

      def to_h
        ret = {}
        ids.each do |id|
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, id)
          ret[name] = get(name)
        end
        ret
      end

      # def genotypes; end

      private

      def get_numeric_values(key, hts_type, expected_type)
        ndst = FFI::MemoryPointer.new(:int)
        ndst.write_int(0)
        dst_ptr = FFI::MemoryPointer.new(:pointer)
        dst_ptr.write_pointer(FFI::Pointer::NULL)

        ret = LibHTS.bcf_get_format_values(@record.header.struct, @record.struct, key, dst_ptr, ndst, hts_type)
        ret = normalize_format_rc(ret, key, expected_type)
        return nil unless ret

        dst = dst_ptr.read_pointer
        begin
          yield(dst, ret)
        ensure
          LibHTS.hts_free(dst) unless dst.null?
          dst_ptr.write_pointer(FFI::Pointer::NULL)
        end
      end

      def get_string_values(key)
        ndst = FFI::MemoryPointer.new(:int)
        ndst.write_int(0)
        dst_ptr = FFI::MemoryPointer.new(:pointer)
        dst_ptr.write_pointer(FFI::Pointer::NULL)

        ret = LibHTS.bcf_get_format_string(@record.header.struct, @record.struct, key, dst_ptr, ndst)
        ret = normalize_format_rc(ret, key, "string")
        return nil unless ret

        dst = dst_ptr.read_pointer
        sample_count = @record.header.nsamples
        begin
          dst.read_array_of_pointer(sample_count).map(&:read_string)
        ensure
          unless dst.null?
            collapsed = sample_count.positive? ? dst.get_pointer(0) : FFI::Pointer::NULL
            LibHTS.hts_free(collapsed) unless collapsed.null?
            LibHTS.hts_free(dst)
          end
          dst_ptr.write_pointer(FFI::Pointer::NULL)
        end
      end

      def decode_integer_values(key)
        values = get_raw(key, :int)
        return nil unless values

        sample_values = split_sample_values(values)
        if scalar_format?(key)
          sample_values.map do |values_per_sample|
            map_integer_missing_value(trim_integer_vector_end(values_per_sample).first)
          end
        else
          sample_values.map do |values_per_sample|
            map_integer_missing(trim_integer_vector_end(values_per_sample))
          end
        end
      end

      def decode_float_values(key)
        values = get_float_words(key)
        return nil unless values

        sample_values = split_sample_values(values)
        if scalar_format?(key)
          sample_values.map do |values_per_sample|
            decode_float_word(trim_float_vector_end(values_per_sample).first)
          end
        else
          sample_values.map do |values_per_sample|
            map_float_words(trim_float_vector_end(values_per_sample))
          end
        end
      end

      def decode_genotypes
        genotypes = get_genotypes
        return nil unless genotypes

        split_sample_values(genotypes).map do |sample_values|
          decode_genotype_sample(trim_genotype_vector_end(sample_values))
        end
      end

      def decode_genotype_sample(values)
        values.each_with_index.map do |value, index|
          allele = if LibHTS.bcf_gt_is_missing(value) != 0
                     "."
                   else
                     LibHTS.bcf_gt_allele(value).to_s
                   end

          next allele if index.zero?

          separator = LibHTS.bcf_gt_is_phased(value) != 0 ? "|" : "/"
          "#{separator}#{allele}"
        end.join
      end

      def split_sample_values(values)
        sample_count = @record.header.nsamples
        return [] if sample_count <= 0

        raise FormatReadError, "Failed to split FORMAT values by sample" unless (values.size % sample_count).zero?

        values_per_sample = values.size / sample_count
        Array.new(sample_count) do |sample_index|
          start = sample_index * values_per_sample
          values[start, values_per_sample]
        end
      end

      def trim_genotype_vector_end(values)
        end_index = values.index { |value| LibHTS.bcf_gt_is_vector_end(value) != 0 } || values.size
        values[0, end_index]
      end

      def trim_integer_vector_end(values)
        end_index = values.index { |value| value == LibHTS.bcf_int32_vector_end } || values.size
        values[0, end_index]
      end

      def trim_float_vector_end(values)
        end_index = values.index(0x7f80_0002) || values.size
        values[0, end_index]
      end

      def map_integer_missing(values)
        values.map { |value| map_integer_missing_value(value) }
      end

      def map_integer_missing_value(value)
        value == LibHTS.bcf_int32_missing ? nil : value
      end

      def map_float_words(values)
        values.map { |value| decode_float_word(value) }
      end

      def decode_float_word(value)
        return nil if value == 0x7f80_0001

        [value].pack("V").unpack1("e")
      end

      def get_float_words(key)
        get_numeric_values(key, LibHTS::BCF_HT_REAL, "float") { |dst, len| dst.get_array_of_uint32(0, len) }
      end

      def normalize_format_rc(rc, key, expected_type)
        case rc
        when -1, -3
          nil
        when -2
          raise FormatTypeError, "Tag #{key} is not #{expected_type} FORMAT field"
        when -4
          raise FormatReadError, "Failed to read FORMAT/#{key}"
        else
          rc
        end
      end

      def raise_unsupported_format_flag(key)
        return unless header_format_type(key) == :flag

        raise UnsupportedFormatOperationError,
              "FORMAT flag fields are not supported: #{key}"
      end

      def ensure_expected_format_type!(key, expected_type, label)
        actual_type = header_format_type(key)
        raise FormatDefinitionError, "FORMAT tag #{key} not defined in header" if actual_type.nil?

        raise_unsupported_format_flag(key)
        raise FormatTypeError, "Tag #{key} is not #{label} FORMAT field" unless actual_type == expected_type
      end

      def ensure_gt_defined!
        raise FormatDefinitionError, "FORMAT tag GT not defined in header" if header_format_type("GT").nil?
      end

      def check_update_rc!(rc, key)
        case rc
        when -1
          raise FormatDefinitionError, "FORMAT tag #{key} not defined in header"
        when 0
          rc
        else
          raise FormatUpdateError, "Failed to update FORMAT field '#{key}': #{rc}" if rc.negative?

          rc
        end
      end

      def validate_numeric_sample_count!(key, value_count)
        sample_count = @record.header.nsamples
        raise ArgumentError, "FORMAT fields require at least one sample" if sample_count <= 0
        return if (value_count % sample_count).zero?

        raise ArgumentError, "FORMAT values for #{key} must be divisible by sample count (#{sample_count})"
      end

      def validate_string_sample_count!(key, value_count)
        sample_count = @record.header.nsamples
        raise ArgumentError, "FORMAT fields require at least one sample" if sample_count <= 0
        return if value_count == sample_count

        raise ArgumentError, "FORMAT string values for #{key} must provide one entry per sample (#{sample_count})"
      end

      def normalize_int_values(values)
        values = Array(values)
        raise ArgumentError, "Cannot update FORMAT field with empty array. Use delete instead." if values.empty?
        raise ArgumentError, "FORMAT integer values must all be Integer" unless values.all?(Integer)
        raise RangeError, "FORMAT integer values must fit int32" unless values.all? { |value| int32_range?(value) }

        values
      end

      def normalize_float_values(values)
        values = Array(values)
        raise ArgumentError, "Cannot update FORMAT field with empty array. Use delete instead." if values.empty?
        raise ArgumentError, "FORMAT float values must all be Numeric" unless values.all?(Numeric)

        values.map(&:to_f)
      end

      def normalize_string_values(values)
        values = Array(values)
        raise ArgumentError, "Cannot update FORMAT field with empty array. Use delete instead." if values.empty?
        raise ArgumentError, "FORMAT string values must all be String" unless values.all?(String)

        values
      end

      def format_present?(key)
        if key == "GT"
          !get_genotypes.nil?
        else
          case header_format_type(key)
          when :int then !get_int(key).nil?
          when :float then !get_float(key).nil?
          when :string then !get_string(key).nil?
          else false
          end
        end
      end

      def fmt_ptr
        @record.struct[:d][:fmt].to_ptr
      end

      def ids
        fmt_ptr.read_array_of_struct(LibHTS::BcfFmt, length).map do |fmt|
          fmt[:id]
        end
      end

      def get_fmt_type(qname)
        @record.struct[:n_fmt].times do |i|
          fmt = LibHTS::BcfFmt.new(@record.struct[:d][:fmt] + i * LibHTS::BcfFmt.size)
          id = fmt[:id]
          name = LibHTS.bcf_hdr_int2id(@record.header.struct, LibHTS::BCF_DT_ID, id)
          if name == qname
            type = LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_FMT, id)
            return type
          end
        end
        nil
      end

      def scalar_format?(key)
        header_format_number(key) == 1
      end

      def header_format_number(key)
        id = LibHTS.bcf_hdr_id2int(@record.header.struct, LibHTS::BCF_DT_ID, key)
        return nil unless LibHTS.bcf_hdr_idinfo_exists(@record.header.struct, LibHTS::BCF_HL_FMT, id)

        LibHTS.bcf_hdr_id2number(@record.header.struct, LibHTS::BCF_HL_FMT, id)
      end

      def header_format_type_code(key)
        id = LibHTS.bcf_hdr_id2int(@record.header.struct, LibHTS::BCF_DT_ID, key)
        return nil unless LibHTS.bcf_hdr_idinfo_exists(@record.header.struct, LibHTS::BCF_HL_FMT, id)

        LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_FMT, id)
      end

      def header_format_type(key)
        ht_type_to_sym(header_format_type_code(key))
      end

      def ht_type_to_sym(t)
        case t
        when LibHTS::BCF_HT_FLAG then :flag
        when LibHTS::BCF_HT_INT then :int
        when LibHTS::BCF_HT_REAL then :float
        when LibHTS::BCF_HT_STR then :string
        when LibHTS::BCF_HT_LONG then :int64
        end
      end

      def int32_range?(value)
        value >= -2_147_483_648 && value <= 2_147_483_647
      end
    end
  end
end
