# frozen_string_literal: true

require_relative "header_record"

module HTS
  class Bcf < Hts
    # A class for working with VCF records.
    # NOTE: This class has a lot of methods that are not stable.
    # The method names and the number of arguments may change in the future.
    class Header
      BCF_TYPE_MAP = {
        int: "Integer",
        integer: "Integer",
        int32: "Integer",
        float: "Float",
        real: "Float",
        string: "String",
        str: "String",
        character: "Character",
        char: "Character",
        flag: "Flag"
      }.freeze

      def initialize(arg = nil)
        case arg
        when Native::BcfHeaderHandle
          @native = arg
        when nil
          @native = Native::BcfHeaderHandle.create
        else
          raise TypeError, "Invalid argument"
        end

        @sync_depth = 0
        @sync_needed = false
        @schema_version = 0
        @subset_samples = nil
        @subset_imap = nil
        @subset_imap_pointer = nil

        yield self if block_given?
      end

      def get_version
        @native.version
      end

      def set_version(version)
        rc = @native.set_version(version)
        raise "Failed to set VCF header version" if rc.negative?

        mark_sync_needed!
        sync_if_needed!
        self
      end

      def nsamples
        @native.nsamples
      end

      def target_count
        target_names.size
      end

      def get_tid(name)
        name2id(name)
      end

      def target_name(rid)
        id2name(rid)
      end

      def target_names
        seqnames
      end

      def samples
        @native.samples
      end

      attr_reader :subset_samples, :subset_imap_pointer, :schema_version

      def subset?
        !@subset_imap.nil?
      end

      def subset_sample_count
        subset? ? @subset_samples.length : 0
      end

      def subset(samples)
        subset_samples = normalize_subset_samples(samples)
        validate_subset_samples!(subset_samples)

        result = @native.subset(subset_samples)
        raise SubsetError, "Failed to subset BCF header samples #{subset_samples.inspect}" unless result

        subset_header, imap = result
        composed_imap = compose_subset_imap(imap)
        self.class.new(subset_header).tap do |header|
          header.send(:set_subset_state, subset_samples, composed_imap)
        end
      end

      def add_sample(sample, sync: true)
        rc = @native.add_sample(sample)
        raise "Failed to add sample #{sample}" if rc.negative?

        mark_sync_needed!
        sync_if_needed! if sync
        self
      end

      def merge(hdr)
        @native.merge(hdr.__send__(:native_handle))
        mark_sync_needed!
        sync_if_needed!
        self
      end

      def sync
        rc = @native.sync
        raise "Failed to sync BCF header" if rc.negative?

        @sync_needed = false
        self
      end

      def read_bcf(fname)
        result = @native.read_file(fname)
        @schema_version += 1 unless result.negative?
        result
      end

      def append(line)
        rc = @native.append(line)
        raise "Failed to append VCF header line" if rc.negative?

        mark_sync_needed!
        self
      end

      def delete(bcf_hl_type, key = nil) # FIXME
        existed = hrec_exists?(bcf_hl_type, key)
        @native.remove(bcf_hl_type.to_s, key)
        mark_sync_needed! if existed
        existed
      end

      def get_hrec(bcf_hl_type, key, value, str_class = nil)
        hrec = @native.get_hrec(bcf_hl_type.to_s, key, value, str_class)
        hrec ? HeaderRecord.new(hrec) : nil
      end

      def edit
        @sync_depth += 1
        yield self
        self
      ensure
        @sync_depth -= 1
        sync_if_needed!
      end

      def add_contig(id, length: nil, **attributes)
        fields = [["ID", id.to_s]]
        fields << ["length", length.to_s] unless length.nil?
        fields.concat normalize_meta_attributes(attributes)
        append_structured_meta("contig", fields)
      end

      def remove_contig(id)
        delete("CONTIG", id.to_s).tap { sync_if_needed! }
      end

      def add_filter(id, description:, **attributes)
        fields = [["ID", id.to_s], ["Description", description.to_s]]
        fields.concat normalize_meta_attributes(attributes)
        append_structured_meta("FILTER", fields)
      end

      def remove_filter(id)
        delete("FILTER", id.to_s).tap { sync_if_needed! }
      end

      def add_info(id, number:, type:, description:, **attributes)
        fields = [["ID", id.to_s], ["Number", normalize_bcf_number(number)], ["Type", normalize_bcf_type(type)],
                  ["Description", description.to_s]]
        fields.concat normalize_meta_attributes(attributes)
        append_structured_meta("INFO", fields)
      end

      def update_info(id, number:, type:, description:, **attributes)
        delete("INFO", id.to_s)
        add_info(id, number:, type:, description:, **attributes)
      end

      def remove_info(id)
        delete("INFO", id.to_s).tap { sync_if_needed! }
      end

      def add_format(id, number:, type:, description:, **attributes)
        fields = [["ID", id.to_s], ["Number", normalize_bcf_number(number)], ["Type", normalize_bcf_type(type)],
                  ["Description", description.to_s]]
        fields.concat normalize_meta_attributes(attributes)
        append_structured_meta("FORMAT", fields)
      end

      def update_format(id, number:, type:, description:, **attributes)
        delete("FORMAT", id.to_s)
        add_format(id, number:, type:, description:, **attributes)
      end

      def remove_format(id)
        delete("FORMAT", id.to_s).tap { sync_if_needed! }
      end

      def add_meta(key, value = nil, **attributes)
        if attributes.empty?
          append("###{key}=#{value}")
          sync_if_needed!
          self
        else
          append_structured_meta(key.to_s, normalize_meta_attributes(attributes))
        end
      end

      def seqnames
        @native.seqnames
      end

      def to_s
        @native.to_s
      end

      def name2id(name)
        @native.name2id(name)
      end

      def id2name(id)
        @native.id2name(id)
      end

      private

      def normalize_bcf_type(type)
        BCF_TYPE_MAP.fetch(type.to_sym, type.to_s)
      end

      def normalize_bcf_number(number)
        case number
        when :a, :A then "A"
        when :r, :R then "R"
        when :g, :G then "G"
        when :variable, :var, :dot then "."
        else number.to_s
        end
      end

      def normalize_meta_attributes(attributes)
        attributes.map do |key, value|
          meta_key = key.to_s.split("_").map.with_index { |part, index| index.zero? ? part : part.capitalize }.join
          meta_value = value.is_a?(Array) ? value.join(",") : value.to_s
          [meta_key, meta_value]
        end
      end

      def append_structured_meta(label, fields)
        body = fields.map { |key, value| "#{key}=#{format_meta_value(key, value)}" }.join(",")
        append("###{label}=<#{body}>")
        sync_if_needed!
        self
      end

      def format_meta_value(key, value)
        return quote_meta_value(value) if key == "Description"
        return value if value.match?(/\A[[:alnum:]_.:+-]+\z/)

        quote_meta_value(value)
      end

      def quote_meta_value(value)
        %("#{value.gsub(/([\\"])/, '\\\\1')}")
      end

      def mark_sync_needed!
        @sync_needed = true
        @schema_version += 1
      end

      def sync_if_needed!
        sync if @sync_needed && @sync_depth.zero?
      end

      def hrec_exists?(bcf_hl_type, key)
        lookup_key, lookup_value, str_class = hrec_lookup_args(bcf_hl_type, key)
        !@native.get_hrec(bcf_hl_type.to_s, lookup_key, lookup_value, str_class).nil?
      end

      def hrec_lookup_args(type, key)
        case type.to_s.upcase
        when "FILTER", "FIL", "INFO", "FORMAT", "FMT", "CONTIG", "CTG"
          ["ID", key, nil]
        when "GENOTYPE", "GEN"
          [key, nil, nil]
        else
          ["ID", key, nil]
        end
      end

      def initialize_copy(orig)
        @native = orig.__send__(:native_handle).duplicate
        @sync_depth = 0
        @sync_needed = false
        @schema_version = orig.schema_version
        set_subset_state(orig.subset_samples, orig.send(:subset_imap))
      end

      protected

      attr_reader :subset_imap

      def set_subset_state(samples, imap)
        @subset_samples = samples&.dup
        @subset_imap = imap&.dup
        @subset_imap_pointer = nil
      end

      private

      def normalize_subset_samples(samples)
        case samples
        when String
          [samples]
        else
          Array(samples).map(&:to_s)
        end
      rescue TypeError
        raise SubsetError, "Sample subset must be a String or an Array of sample names"
      end

      def validate_subset_samples!(subset_samples)
        duplicates = subset_samples.group_by(&:itself).select { |_name, group| group.length > 1 }.keys
        raise SubsetError, "Duplicate sample names in subset: #{duplicates.join(', ')}" unless duplicates.empty?

        missing = subset_samples.reject { |name| samples.include?(name) }
        raise UnknownSampleError, "Unknown sample names: #{missing.join(', ')}" unless missing.empty?
      end

      def compose_subset_imap(imap)
        base_imap = @subset_imap || Array.new(samples.length, &:itself)
        imap.map { |index| base_imap.fetch(index) }
      end

      def native_handle = @native
    end
  end
end
