# frozen_string_literal: true

module HTS
  class Bcf < Hts
    class Format
      GT_MISSING = 0
      GT_VECTOR_END = Native::BCF_INT32_VECTOR_END

      class << self
        def gt_unphased(allele) = (Integer(allele) + 1) << 1
        def gt_phased(allele) = ((Integer(allele) + 1) << 1) | 1
        def gt_allele(value) = (Integer(value) >> 1) - 1
        def gt_missing?(value) = (Integer(value) >> 1).zero?
        def gt_phased?(value) = (Integer(value) & 1) == 1
        def gt_vector_end?(value) = Integer(value) == GT_VECTOR_END
      end

      BufferState = Struct.new(:generation)

      class NumericVectorView
        include Enumerable
        def initialize(type) = @type = type
        def reset(values, buffer, generation)
          @values = values
          @buffer = buffer
          @generation = generation
          self
        end
        def each
          return to_enum(__method__) unless block_given?
          ensure_valid!
          @values.each { |value| yield value }
          self
        end
        def to_a = each.to_a
        private
        def ensure_valid!
          raise InvalidBorrowedViewError, "borrowed FORMAT view is no longer valid" unless @buffer.generation == @generation
        end
      end

      class GenotypeView
        include Enumerable

        def reset(values, buffer, generation)
          @values = values
          @buffer = buffer
          @generation = generation
          self
        end
        def each_allele
          return to_enum(__method__) unless block_given?
          ensure_valid!
          @values.each do |encoded|
            break if encoded == GT_VECTOR_END
            missing = gt_missing?(encoded)
            yield(missing ? nil : gt_allele(encoded), gt_phased?(encoded), missing)
          end
          self
        end
        alias each each_allele
        def to_s
          result = +""
          each_allele.with_index do |(allele, phased, missing), index|
            result << (phased && index.positive? ? "|" : "/") if index.positive?
            result << (missing ? "." : allele.to_s)
          end
          result
        end
        private
        def ensure_valid!
          raise InvalidBorrowedViewError, "borrowed FORMAT view is no longer valid" unless @buffer.generation == @generation
        end
        def gt_missing?(value) = (value >> 1).zero?
        def gt_allele(value) = (value >> 1) - 1
        def gt_phased?(value) = (value & 1) == 1
      end

      def initialize(record)
        @record = record
        @buffers = {}
      end

      def get(key, type = nil)
        key = key.to_s
        schema = format_schema(key)
        return nil unless schema
        raise_unsupported_flag(key) if schema.first == :flag

        requested = type&.to_sym
        if requested && !type_compatible?(schema.first, requested, key)
          raise FormatTypeError, "Tag #{key} is not #{type_label(requested)} FORMAT field"
        end
        return genotype_strings(key) if key == "GT" && (!requested || %i[string str].include?(requested))

        return get_float(key) if %i[float real].include?(requested)
        raw = get_raw(key, requested)
        return raw if requested
        return raw if schema.first == :string

        shape_values(raw, key, schema)
      end

      def get_raw(key, type = nil)
        key = key.to_s
        schema = format_schema(key)
        return nil unless schema
        requested = type&.to_sym
        if requested && !type_compatible?(schema.first, requested, key)
          raise FormatTypeError, "Tag #{key} is not #{type_label(requested)} FORMAT field"
        end
        code = key == "GT" ? Native::BCF_HT_INT : type_code(requested || schema.first)
        raw_float = code == Native::BCF_HT_REAL
        invalidate_views!(key)
        native.format_get(header_native, key, code, raw_float)
      end

      def get_int(key) = get(key, :int)
      def get_float(key)
        words = get_raw(key, :float)
        words&.map { |word| decode_float_word(word) }
      end
      def get_flag(key) = get(key, :flag)
      def get_string(key) = get(key, :string)
      def get_genotypes = get_raw("GT", :int)
      def [](key) = get(key)

      def each_genotype(key = "GT")
        return enum_for(__method__, key) unless block_given?
        raise ArgumentError, "genotype FORMAT key must be GT" unless key.to_s == "GT"

        values = get_raw(key, :int)
        return nil unless values
        count, width = sample_layout(values.length)
        buffer, generation = advance_buffer(key, :genotype)
        view = GenotypeView.new
        count.times do |sample|
          yield sample, view.reset(values.slice(sample * width, width), buffer, generation)
        end
        self
      end

      def genotype_at(key, sample_index)
        values = get_raw(key, :int)
        return nil unless values
        count, width = sample_layout(values.length)
        sample_index = Integer(sample_index)
        sample_index += count if sample_index.negative?
        raise IndexError, "sample index #{sample_index} outside of FORMAT" unless sample_index.between?(0, count - 1)
        buffer, generation = advance_buffer(key, :genotype)
        GenotypeView.new.reset(values.slice(sample_index * width, width), buffer, generation)
      end

      def genotype_strings(key = "GT")
        strings = []
        found = each_genotype(key) { |_, genotype| strings << genotype.to_s }
        found ? strings : nil
      end

      def each_i32(key)
        return enum_for(__method__, key) unless block_given?
        ensure_scalar!(key, :int)
        values = get_raw(key, :int)
        return self unless values
        values.each_with_index { |value, index| yield index, missing_int(value) }
        self
      end

      def each_i32_vector(key, &block) = each_vector(key, :int, &block)
      def each_f32_vector(key, &block) = each_vector(key, :float, &block)

      def update_int(key, values)
        raise UnsupportedFormatOperationError, "Use update_genotypes for GT" if key.to_s == "GT"
        values = normalize_values(values) { |value| Integer(value) }
        validate_sample_divisibility!(key, values.length)
        update_format(key, Native::BCF_HT_INT, values)
      end

      def update_float(key, values)
        values = normalize_values(values, &:to_f)
        validate_sample_divisibility!(key, values.length)
        update_format(key, Native::BCF_HT_REAL, values)
      end

      def update_float_words(key, values)
        values = normalize_values(values) { |value| Integer(value) }
        validate_sample_divisibility!(key, values.length)
        raise FormatDefinitionError, "FORMAT tag #{key} not defined in header" unless format_schema(key)
        result = native.format_update_float_words(header_native, key.to_s, values)
        raise FormatUpdateError, "Failed to update FORMAT field '#{key}': #{result}" if result.negative?
        result
      end

      def update_string(key, values)
        values = Array(values).map(&:to_s)
        expected = sample_count
        unless values.length == expected
          raise ArgumentError, "FORMAT string values for #{key} must provide one entry per sample (#{expected})"
        end
        update_format(key, Native::BCF_HT_STR, values)
      end

      def update_genotypes(values)
        values = normalize_values(values) { |value| Integer(value) }
        validate_sample_divisibility!("GT", values.length)
        result = native.genotype_update(header_native, values)
        raise FormatUpdateError, "Failed to update FORMAT field 'GT': #{result}" if result.negative?
        result
      end

      def delete(key)
        schema = format_schema(key)
        return false unless schema && !get_raw(key).nil?
        result = native.format_delete(header_native, key.to_s, type_code(schema.first))
        result >= 0
      end

      def fields = native.format_fields(header_native)
      def ids = fields.map { |field| field[:id] }
      def get_float_words(key) = get_raw(key, :float)
      def length = fields.length
      alias size length
      def to_h = fields.to_h { |field| [field[:name], get(field[:name])] }

      private

      def native = @record.__send__(:native_handle)
      def header_native = @record.header.__send__(:native_handle)
      def sample_count = @record.header.nsamples
      def format_schema(key) = header_native.schema("FORMAT", key.to_s)

      def type_code(type)
        { int: Native::BCF_HT_INT, int32: Native::BCF_HT_INT,
          float: Native::BCF_HT_REAL, real: Native::BCF_HT_REAL,
          string: Native::BCF_HT_STR, str: Native::BCF_HT_STR }.fetch(type)
      end

      def type_compatible?(actual, requested, key)
        return true if key == "GT" && %i[int int32 string str].include?(requested)
        case requested
        when :int, :int32 then actual == :int
        when :float, :real then actual == :float
        when :string, :str then actual == :string
        when :flag then actual == :flag
        else actual == requested
        end
      end

      def type_label(type)
        case type
        when :int, :int32 then "integer"
        when :float, :real then "float"
        when :string, :str then "string"
        else type.to_s
        end
      end

      def raise_unsupported_flag(key)
        raise UnsupportedFormatOperationError, "FORMAT flag fields are not supported: #{key}"
      end

      def sample_layout(value_count)
        count = sample_count
        raise FormatReadError, "invalid FORMAT sample layout" if count <= 0 || (value_count % count) != 0
        [count, value_count / count]
      end

      def shape_values(values, key, schema)
        return nil unless values
        count, width = sample_layout(values.length)
        scalar = schema[1] == 1
        Array.new(count) do |sample|
          row = values.slice(sample * width, width)
          row = trim_vector(row, schema.first)
          scalar ? row.first : row
        end
      end

      def trim_vector(values, type)
        if type == :int
          values.take_while { |value| value != Native::BCF_INT32_VECTOR_END }.map { |value| missing_int(value) }
        else
          values.take_while { |word| word != Native::BCF_FLOAT_VECTOR_END }.map { |word| decode_float_word(word) }
        end
      end

      def missing_int(value)
        [Native::BCF_INT32_MISSING, Native::BCF_INT32_VECTOR_END].include?(value) ? nil : value
      end
      def decode_float_word(word)
        return nil if word == Native::BCF_FLOAT_MISSING || word == Native::BCF_FLOAT_VECTOR_END
        [word].pack("L<").unpack1("e")
      end

      def advance_buffer(key, type)
        buffer = (@buffers[[key.to_s, type]] ||= BufferState.new(0))
        buffer.generation += 1
        [buffer, buffer.generation]
      end

      def invalidate_views!(key)
        @buffers.each do |(buffer_key, _type), buffer|
          buffer.generation += 1 if buffer_key == key.to_s
        end
      end

      def each_vector(key, type)
        return enum_for(type == :int ? :each_i32_vector : :each_f32_vector, key) unless block_given?
        values = get_raw(key, type)
        return self unless values
        count, width = sample_layout(values.length)
        buffer, generation = advance_buffer(key, type)
        view = NumericVectorView.new(type)
        count.times do |sample|
          decoded = trim_vector(values.slice(sample * width, width), type)
          yield sample, view.reset(decoded, buffer, generation)
        end
        self
      end

      def ensure_scalar!(key, expected)
        schema = format_schema(key)
        return unless schema
        raise FormatTypeError, "Tag #{key} is not #{type_label(expected)} FORMAT field" unless schema.first == expected
        raise FormatReadError, "FORMAT field #{key} is not scalar" unless schema[1] == 1
      end

      def normalize_values(values)
        Array(values).map { |value| yield value }
      end

      def validate_sample_divisibility!(key, count)
        samples = sample_count
        return if samples.positive? && (count % samples).zero?
        raise ArgumentError, "FORMAT values for #{key} must be divisible by sample count (#{samples})"
      end

      def update_format(key, type, values)
        schema = format_schema(key)
        raise FormatDefinitionError, "FORMAT tag #{key} not defined in header" unless schema
        expected = type_code(schema.first)
        unless expected == type
          requested = { Native::BCF_HT_INT => :int, Native::BCF_HT_REAL => :float,
                        Native::BCF_HT_STR => :string }.fetch(type)
          raise FormatTypeError, "Tag #{key} is not #{type_label(requested)} FORMAT field"
        end
        result = native.format_update(header_native, key.to_s, type, values)
        raise FormatUpdateError, "Failed to update FORMAT field '#{key}': #{result}" if result.negative?
        result
      end
    end
  end
end
