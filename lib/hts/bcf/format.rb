# frozen_string_literal: true

module HTS
  class Bcf < Hts
    class Format
      # Borrowed, reusable view over one sample's numeric FORMAT values.
      # The view is valid only until the accessor advances to the next sample or
      # fetches the same FORMAT field again. Call #to_a to retain its values.
      class NumericVectorView
        include Enumerable

        def initialize(type)
          @type = type
        end

        def reset(pointer, offset, length, buffer, generation)
          @pointer = pointer
          @offset = offset
          @length = length
          @buffer = buffer
          @generation = generation
          self
        end

        def each
          return to_enum(__method__) unless block_given?

          @length.times do |index|
            ensure_valid!
            byte_offset = (@offset + index) * 4
            word = @pointer.get_uint32(byte_offset)
            break if vector_end?(word)

            yield decode(word, byte_offset)
          end
          self
        end

        def to_a
          each.to_a
        end

        private

        def ensure_valid!
          return if @buffer.generation == @generation

          raise InvalidBorrowedViewError,
                "borrowed FORMAT view is no longer valid; consume it before another getter for the same field"
        end

        def vector_end?(word)
          if @type == :int32
            word == (LibHTS.bcf_int32_vector_end & 0xffff_ffff)
          else
            word == LibHTS.bcf_float_vector_end
          end
        end

        def decode(word, byte_offset)
          if @type == :int32
            return nil if word == (LibHTS.bcf_int32_missing & 0xffff_ffff)

            @pointer.get_int32(byte_offset)
          else
            return nil if word == LibHTS.bcf_float_missing

            @pointer.get_float32(byte_offset)
          end
        end
      end

      # Borrowed view over one sample's encoded GT values.
      class GenotypeView
        include Enumerable

        def reset(pointer, offset, length, buffer, generation)
          @pointer = pointer
          @offset = offset
          @length = length
          @buffer = buffer
          @generation = generation
          self
        end

        def each_allele
          return to_enum(__method__) unless block_given?

          @length.times do |index|
            ensure_valid!
            value = @pointer.get_int32((@offset + index) * 4)
            break if LibHTS.bcf_gt_is_vector_end(value) != 0

            missing = LibHTS.bcf_gt_is_missing(value) != 0
            allele = missing ? nil : LibHTS.bcf_gt_allele(value)
            phased = LibHTS.bcf_gt_is_phased(value) != 0
            yield allele, phased, missing
          end
          self
        end

        alias each each_allele

        def to_s
          result = String.new
          each_allele.with_index do |(allele, phased, missing), index|
            result << (phased ? "|" : "/") unless index.zero?
            result << (missing ? "." : allele.to_s)
          end
          result
        end

        private

        def ensure_valid!
          return if @buffer.generation == @generation

          raise InvalidBorrowedViewError,
                "borrowed FORMAT view is no longer valid; consume it before another getter for the same field"
        end
      end

      def initialize(record)
        @record = record
        @buffers = {}
        @schema_cache = {}
        @schema_version = record.header.schema_version
        @int_vector_view = NumericVectorView.new(:int32)
        @float_vector_view = NumericVectorView.new(:float32)
        @genotype_view = GenotypeView.new
      end

      # @note: Why is this method named "get" instead of "fetch"?
      # This is for compatibility with the Crystal language
      # which provides methods like `get_int`, `get_float`, etc.
      # I think they are better than `fetch_int`` and `fetch_float`.
      def get(key, type = nil)
        return get_typed(key, type) unless type.nil?

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
          get_float_words(key)
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
        get_typed(key, :float)
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

      # Iterate encoded genotypes without creating per-sample arrays or strings.
      # The yielded GenotypeView is reused; call #to_s or collect primitive values
      # inside the block if they must outlive the current yield.
      def each_genotype(key = "GT")
        return to_enum(__method__, key) unless block_given?
        raise ArgumentError, "genotype FORMAT key must be GT" unless key == "GT"

        found = with_numeric_values(key, LibHTS::BCF_HT_INT, "genotype") do |pointer, count, buffer, generation|
          each_sample_offset(count) do |sample_index, offset, width|
            yield sample_index, @genotype_view.reset(pointer, offset, width, buffer, generation)
          end
        end
        found ? self : nil
      end

      # Return a borrowed view for one sample. It remains valid only until the
      # next GT getter call on this accessor. Getters for other keys are safe.
      def genotype_at(key, sample_index)
        raise ArgumentError, "genotype FORMAT key must be GT" unless key == "GT"

        view = nil
        with_numeric_values(key, LibHTS::BCF_HT_INT, "genotype") do |pointer, count, buffer, generation|
          sample_count, width = sample_layout(count)
          index = normalize_sample_index(sample_index, sample_count)
          view = GenotypeView.new.reset(pointer, index * width, width, buffer, generation)
        end
        view
      end

      # Owning, allocating genotype-string convenience API.
      def genotype_strings(key = "GT")
        strings = []
        found = each_genotype(key) { |_sample_index, genotype| strings << genotype.to_s }
        found ? strings : nil
      end

      # Iterate a Number=1 integer FORMAT field without nested arrays.
      def each_i32(key)
        return to_enum(__method__, key) unless block_given?
        ensure_scalar_format!(key, :int)

        with_numeric_values(key, LibHTS::BCF_HT_INT, "integer") do |pointer, count|
          each_sample_offset(count) do |sample_index, offset, _width|
            value = pointer.get_int32(offset * 4)
            value = nil if value == LibHTS.bcf_int32_missing || value == LibHTS.bcf_int32_vector_end
            yield sample_index, value
          end
        end
        self
      end

      # The yielded view is reused. Use #to_a only when an owning array is needed.
      def each_i32_vector(key)
        return to_enum(__method__, key) unless block_given?
        ensure_expected_format_type!(key, :int, "integer")

        with_numeric_values(key, LibHTS::BCF_HT_INT, "integer") do |pointer, count, buffer, generation|
          each_sample_offset(count) do |sample_index, offset, width|
            yield sample_index, @int_vector_view.reset(pointer, offset, width, buffer, generation)
          end
        end
        self
      end

      # The yielded view is reused. Float sentinel words are inspected before
      # reading native float values, avoiding per-element pack/unpack.
      def each_f32_vector(key)
        return to_enum(__method__, key) unless block_given?
        ensure_expected_format_type!(key, :float, "float")

        with_numeric_values(key, LibHTS::BCF_HT_REAL, "float") do |pointer, count, buffer, generation|
          each_sample_offset(count) do |sample_index, offset, width|
            yield sample_index, @float_vector_view.reset(pointer, offset, width, buffer, generation)
          end
        end
        self
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
        result = nil
        found = with_numeric_values(key, hts_type, expected_type) do |pointer, count|
          result = yield(pointer, count)
        end
        found ? result : nil
      end

      def with_numeric_values(key, hts_type, expected_type)
        buffer = buffer_for(hts_type, key)
        buffer.advance!
        count = LibHTS.bcf_get_format_values(
          @record.header.struct, @record.struct, key,
          buffer.dst_pointer, buffer.capacity_pointer, hts_type
        )
        count = normalize_format_rc(count, key, expected_type)
        return false unless count

        yield buffer.pointer, count, buffer, buffer.generation
        true
      end

      def buffer_for(type, key)
        buffers_for_type = (@buffers[type] ||= {})
        buffers_for_type[key] ||= GetterBuffer.new
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
        if scalar_format?(key)
          values = []
          found = false
          each_i32(key) { |_sample_index, value| found = true; values << value }
          found ? values : nil
        else
          values = []
          found = false
          each_i32_vector(key) { |_sample_index, view| found = true; values << view.to_a }
          found ? values : nil
        end
      end

      def decode_float_values(key)
        values = []
        found = false
        if scalar_format?(key)
          each_f32_vector(key) do |_sample_index, view|
            found = true
            values << view.each.first
          end
        else
          each_f32_vector(key) { |_sample_index, view| found = true; values << view.to_a }
        end
        found ? values : nil
      end

      def decode_genotypes
        genotype_strings
      end

      def get_float_words(key)
        get_numeric_values(key, LibHTS::BCF_HT_REAL, "float") { |dst, len| dst.get_array_of_uint32(0, len) }
      end

      def get_typed(key, type)
        case type.to_sym
        when :float, :real
          raise_unsupported_format_flag(key)
          values = []
          found = with_numeric_values(key, LibHTS::BCF_HT_REAL, "float") do |pointer, count|
            count.times do |index|
              offset = index * 4
              word = pointer.get_uint32(offset)
              values << if word == LibHTS.bcf_float_missing || word == LibHTS.bcf_float_vector_end
                          nil
                        else
                          pointer.get_float32(offset)
                        end
            end
          end
          found ? values : nil
        else
          get_raw(key, type)
        end
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

      def ensure_scalar_format!(key, type)
        label = type == :int ? "integer" : "float"
        ensure_expected_format_type!(key, type, label)
        return if scalar_format?(key)

        raise ArgumentError, "FORMAT/#{key} is not a Number=1 field"
      end

      def sample_layout(value_count)
        sample_count = @record.header.nsamples
        raise FormatReadError, "FORMAT fields require at least one sample" if sample_count <= 0
        unless (value_count % sample_count).zero?
          raise FormatReadError, "Failed to split FORMAT values by sample"
        end

        [sample_count, value_count / sample_count]
      end

      def each_sample_offset(value_count)
        sample_count, width = sample_layout(value_count)
        sample_count.times { |sample_index| yield sample_index, sample_index * width, width }
      end

      def normalize_sample_index(sample_index, sample_count)
        index = Integer(sample_index)
        index += sample_count if index.negative?
        raise IndexError, "sample index #{sample_index} outside 0...#{sample_count}" unless index.between?(0, sample_count - 1)

        index
      end

      def header_format_number(key)
        schema = header_format_schema(key)
        schema && schema[:number]
      end

      def header_format_type_code(key)
        schema = header_format_schema(key)
        schema && schema[:type]
      end

      def header_format_schema(key)
        refresh_schema_cache!
        return @schema_cache[key] if @schema_cache.key?(key)

        id = LibHTS.bcf_hdr_id2int(@record.header.struct, LibHTS::BCF_DT_ID, key)
        return @schema_cache[key] = nil if id.negative?
        unless LibHTS.bcf_hdr_idinfo_exists(@record.header.struct, LibHTS::BCF_HL_FMT, id)
          return @schema_cache[key] = nil
        end

        @schema_cache[key] = {
          id: id,
          type: LibHTS.bcf_hdr_id2type(@record.header.struct, LibHTS::BCF_HL_FMT, id),
          number: LibHTS.bcf_hdr_id2number(@record.header.struct, LibHTS::BCF_HL_FMT, id)
        }
      end

      def refresh_schema_cache!
        version = @record.header.schema_version
        return if version == @schema_version

        @schema_cache.clear
        @schema_version = version
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
