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
        when LibHTS::HtsFile
          @bcf_hdr = LibHTS.bcf_hdr_read(arg)
        when LibHTS::BcfHdr
          @bcf_hdr = arg
        when nil
          @bcf_hdr = LibHTS.bcf_hdr_init("w")
        else
          raise TypeError, "Invalid argument"
        end

        @sync_depth = 0
        @sync_needed = false
        @subset_samples = nil
        @subset_imap = nil
        @subset_imap_pointer = nil

        yield self if block_given?
      end

      def struct
        @bcf_hdr
      end

      def to_ptr
        @bcf_hdr.to_ptr
      end

      def get_version
        LibHTS.bcf_hdr_get_version(@bcf_hdr)
      end

      def set_version(version)
        rc = LibHTS.bcf_hdr_set_version(@bcf_hdr, version)
        raise "Failed to set VCF header version" if rc.negative?

        mark_sync_needed!
        sync_if_needed!
        self
      end

      def nsamples
        LibHTS.bcf_hdr_nsamples(@bcf_hdr)
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
        # bcf_hdr_id2name is macro function
        @bcf_hdr[:samples]
          .read_array_of_pointer(nsamples)
          .map(&:read_string)
      end

      attr_reader :subset_samples

      def subset?( )
        !@subset_imap.nil?
      end

      def subset_sample_count
        subset? ? @subset_samples.length : 0
      end

      def subset_imap_pointer
        @subset_imap_pointer
      end

      def subset(samples)
        subset_samples = normalize_subset_samples(samples)
        validate_subset_samples!(subset_samples)

        sample_pointers = nil
        imap_pointer = nil
        if subset_samples.empty?
          subset_hdr = LibHTS.bcf_hdr_subset(@bcf_hdr, 0, ::FFI::Pointer::NULL, ::FFI::Pointer::NULL)
        else
          encoded_samples = subset_samples.map { |name| FFI::MemoryPointer.from_string(name) }
          sample_pointers = FFI::MemoryPointer.new(:pointer, subset_samples.length)
          sample_pointers.write_array_of_pointer(encoded_samples)
          imap_pointer = FFI::MemoryPointer.new(:int, subset_samples.length)
          subset_hdr = LibHTS.bcf_hdr_subset(@bcf_hdr, subset_samples.length, sample_pointers, imap_pointer)
        end

        raise SubsetError, "Failed to subset BCF header samples #{subset_samples.inspect}" if subset_hdr.to_ptr.null?

        composed_imap = compose_subset_imap(read_subset_imap(imap_pointer, subset_samples.length))
        self.class.new(subset_hdr).tap do |header|
          header.send(:set_subset_state, subset_samples, composed_imap)
        end
      end

      def add_sample(sample, sync: true)
        rc = LibHTS.bcf_hdr_add_sample(@bcf_hdr, sample)
        raise "Failed to add sample #{sample}" if rc.negative?

        mark_sync_needed!
        sync_if_needed! if sync
        self
      end

      def merge(hdr)
        merged = LibHTS.bcf_hdr_merge(@bcf_hdr, hdr.struct)
        raise "Failed to merge BCF headers" if merged.to_ptr.null?

        mark_sync_needed!
        sync_if_needed!
        self
      end

      def sync
        rc = LibHTS.bcf_hdr_sync(@bcf_hdr)
        raise "Failed to sync BCF header" if rc.negative?

        @sync_needed = false
        self
      end

      def read_bcf(fname)
        LibHTS.bcf_hdr_set(@bcf_hdr, fname)
      end

      def append(line)
        rc = LibHTS.bcf_hdr_append(@bcf_hdr, line)
        raise "Failed to append VCF header line" if rc.negative?

        mark_sync_needed!
        self
      end

      def delete(bcf_hl_type, key = nil) # FIXME
        existed = hrec_exists?(bcf_hl_type, key)
        type = bcf_hl_type_to_int(bcf_hl_type)
        LibHTS.bcf_hdr_remove(@bcf_hdr, type, key)
        mark_sync_needed! if existed
        existed
      end

      def get_hrec(bcf_hl_type, key, value, str_class = nil)
        type = bcf_hl_type_to_int(bcf_hl_type)
        hrec = borrowed_hrec(type, key, value, str_class)
        return nil if hrec.to_ptr.null?

        HeaderRecord.new(hrec)
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
        fields = [["ID", id.to_s], ["Number", normalize_bcf_number(number)], ["Type", normalize_bcf_type(type)], ["Description", description.to_s]]
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
        fields = [["ID", id.to_s], ["Number", normalize_bcf_number(number)], ["Type", normalize_bcf_type(type)], ["Description", description.to_s]]
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
        n = FFI::MemoryPointer.new(:int)
        names = LibHTS.bcf_hdr_seqnames(@bcf_hdr, n)
        begin
          names.read_array_of_pointer(n.read_int)
               .map(&:read_string)
        ensure
          LibHTS.hts_free(names) unless names.null?
        end
      end

      def to_s
        kstr = LibHTS::KString.new
        begin
          raise "Failed to get header string" unless LibHTS.bcf_hdr_format(@bcf_hdr, 0, kstr)

          kstr.read_string_copy
        ensure
          kstr.free_buffer
        end
      end

      def name2id(name)
        LibHTS.bcf_hdr_name2id(@bcf_hdr, name)
      end

      def id2name(id)
        LibHTS.bcf_hdr_id2name(@bcf_hdr, id)
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
      end

      def sync_if_needed!
        sync if @sync_needed && @sync_depth.zero?
      end

      def hrec_exists?(bcf_hl_type, key)
        type = bcf_hl_type_to_int(bcf_hl_type)
        lookup_key, lookup_value, str_class = hrec_lookup_args(type, key)
        hrec = borrowed_hrec(type, lookup_key, lookup_value, str_class)
        !hrec.to_ptr.null?
      end

      def borrowed_hrec(type, key, value, str_class)
        hrec = LibHTS.bcf_hdr_get_hrec(@bcf_hdr, type, key, value, str_class)
        pointer = hrec.to_ptr
        pointer.autorelease = false if pointer.respond_to?(:autorelease=)
        hrec
      end

      def hrec_lookup_args(type, key)
        case type
        when LibHTS::BCF_HL_FLT, LibHTS::BCF_HL_INFO, LibHTS::BCF_HL_FMT, LibHTS::BCF_HL_CTG
          ["ID", key, nil]
        when LibHTS::BCF_HL_GEN
          [key, nil, nil]
        else
          ["ID", key, nil]
        end
      end

      def bcf_hl_type_to_int(bcf_hl_type)
        return bcf_hl_type if bcf_hl_type.is_a?(Integer)

        case bcf_hl_type.to_s.upcase
        when "FILTER", "FIL"
          LibHTS::BCF_HL_FLT
        when "INFO"
          LibHTS::BCF_HL_INFO
        when "FORMAT", "FMT"
          LibHTS::BCF_HL_FMT
        when "CONTIG", "CTG"
          LibHTS::BCF_HL_CTG
        when "STRUCTURED", "STR"
          LibHTS::BCF_HL_STR
        when "GENOTYPE", "GEN"
          LibHTS::BCF_HL_GEN
        else
          raise TypeError, "Invalid argument"
        end
      end

      def initialize_copy(orig)
        @bcf_hdr = LibHTS.bcf_hdr_dup(orig.struct)
        @sync_depth = 0
        @sync_needed = false
        set_subset_state(orig.subset_samples, orig.send(:subset_imap))
      end

      protected

      attr_reader :subset_imap

      def set_subset_state(samples, imap)
        @subset_samples = samples&.dup
        @subset_imap = imap&.dup
        @subset_imap_pointer = build_subset_imap_pointer(@subset_imap)
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

      def read_subset_imap(pointer, length)
        return [] if length.zero?

        pointer.read_array_of_int(length)
      end

      def compose_subset_imap(imap)
        base_imap = @subset_imap || Array.new(samples.length, &:itself)
        imap.map { |index| base_imap.fetch(index) }
      end

      def build_subset_imap_pointer(imap)
        return nil unless imap
        return nil if imap.empty?

        FFI::MemoryPointer.new(:int, imap.length).tap do |pointer|
          pointer.write_array_of_int(imap)
        end
      end
    end
  end
end
