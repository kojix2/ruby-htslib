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
        @native.set_id(@header.__send__(:native_handle), value)
      end

      def clear_id = @native.set_id(@header.__send__(:native_handle), ".")
      nil
      def alleles = @native.alleles
      def ref = alleles.first
      def alt = alleles.drop(1)
      def allele_count = alleles.length

      def alleles=(values)
        values = Array(values).map(&:to_s)
        raise ArgumentError, "at least one allele is required" if values.empty?

        @native.set_alleles(@header.__send__(:native_handle), values.join(","))
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

      def filter
        names = @native.filter_names(@header.__send__(:native_handle))
        case names.length
        when 0 then "PASS"
        when 1 then names.first
        else names
        end
      end

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
