# frozen_string_literal: true

module HTS
  class Bcf < Hts
    class Record
      attr_reader :header

      def initialize(header, native_record = nil)
        @native = native_record || Native::BcfRecordHandle.create
        @header = header
      end

      def rid = @native.core_get(:rid)

      def rid=(value)
        @native.core_set(:rid, value)
      end

      def chrom = @header.id2name(rid)
      def pos = @native.core_get(:pos)

      def pos=(value)
        @native.core_set(:pos, value)
      end

      def endpos = pos + @native.core_get(:rlen)
      def id = @native.id

      def id=(value)
        check_update_rc!(@native.set_id(@header.__send__(:native_handle), value), "ID", value)
        value
      end

      def clear_id
        check_update_rc!(@native.set_id(@header.__send__(:native_handle), "."), "ID", ".")
        nil
      end

      def alleles = @native.alleles
      def ref = alleles.first
      def alt = alleles.drop(1)
      def allele_count = alleles.length

      def alleles=(values)
        values = Array(values).map(&:to_s)
        raise ArgumentError, "at least one allele is required" if values.empty?

        encoded = values.join(",")
        check_update_rc!(@native.set_alleles(@header.__send__(:native_handle), encoded), "alleles", encoded)
        values
      end

      # Native migration replacement for the former pointer-yielding API.
      def each_allele_raw
        return to_enum(__method__) unless block_given?

        alleles.each { |allele| yield allele, allele.bytesize }
        self
      end

      def qual = @native.core_get(:qual)

      def qual=(value)
        @native.core_set(:qual, value)
      end

      def filters
        names = @native.filter_names(@header.__send__(:native_handle))
        names.empty? ? ["PASS"] : names
      end


      # VCF FILTER is a list even when it contains a single value. Keeping a
      # stable return type avoids substring matching for single-filter records.
      alias filter filters

      def passed? = filters == ["PASS"]
      def filtered? = !passed?

      def each_filter_id(&block)
        return to_enum(__method__) unless block_given?

        @native.filter_ids.each(&block)
        self
      end

      def filter_ids = @native.filter_ids
      def filter_id?(target_id) = filter_ids.include?(Integer(target_id))

      def info(key = nil)
        accessor = (@info_accessor ||= Info.new(self))
        key ? accessor.get(key) : accessor
      end

      def format(key = nil)
        accessor = (@format_accessor ||= Format.new(self))
        key ? accessor.get(key) : accessor
      end

      def to_s = @native.format_record(@header.__send__(:native_handle))

      private

      def check_update_rc!(result, field, value)
        return result unless result.negative?

        raise RecordError, "Failed to update #{field} to #{value.inspect} (HTSlib error #{result})"
      end

      def native_handle = @native

      def initialize_copy(original)
        super
        @header = original.header
        @native = original.__send__(:native_handle).duplicate
        @info_accessor = nil
        @format_accessor = nil
      end
    end
  end
end
