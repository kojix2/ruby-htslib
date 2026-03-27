# frozen_string_literal: true

require_relative "header_record"

module HTS
  class Bam < Hts
    # A class for working with alignment header.
    class Header
      def self.parse(text)
        new(LibHTS.sam_hdr_parse(text.size, text))
      end

      def initialize(arg = nil)
        case arg
        when LibHTS::HtsFile
          @sam_hdr = LibHTS.sam_hdr_read(arg)
        when LibHTS::SamHdr
          @sam_hdr = arg
        when nil
          @sam_hdr = LibHTS.sam_hdr_init
        else
          raise TypeError, "Invalid argument"
        end

        yield self if block_given?
      end

      def struct
        @sam_hdr
      end

      def to_ptr
        @sam_hdr.to_ptr
      end

      def targets
        Array.new(target_count) do |i|
          name = LibHTS.sam_hdr_tid2name(@sam_hdr, i)
          len = LibHTS.sam_hdr_tid2len(@sam_hdr, i)
          { name:, len: }
        end
      end

      def target_count
        # FIXME: sam_hdr_nref
        @sam_hdr[:n_targets]
      end

      def target_name(tid)
        tid2name(tid)
      end

      def target_names
        Array.new(target_count) do |i|
          LibHTS.sam_hdr_tid2name(@sam_hdr, i)
        end
      end

      def target_len
        Array.new(target_count) do |i|
          LibHTS.sam_hdr_tid2len(@sam_hdr, i)
        end
      end

      def write(...)
        add_lines(...)
      end

      # experimental
      def <<(obj)
        case obj
        when Array, Hash
          args = obj.flatten(-1).map { |i| i.to_a if i.is_a?(Hash) }
          add_line(*args)
        else
          add_lines(obj.to_s)
        end
        self
      end

      # experimental
      def find_line(type, key, value)
        ks = LibHTS::KString.new
        begin
          r = LibHTS.sam_hdr_find_line_id(@sam_hdr, type, key, value, ks)
          r == 0 ? ks.read_string_copy : nil
        ensure
          ks.free_buffer
        end
      end

      # experimental
      def find_line_at(type, pos)
        ks = LibHTS::KString.new
        begin
          r = LibHTS.sam_hdr_find_line_pos(@sam_hdr, type, pos, ks)
          r == 0 ? ks.read_string_copy : nil
        ensure
          ks.free_buffer
        end
      end

      # experimental
      def remove_line(type, key, value)
        LibHTS.sam_hdr_remove_line_id(@sam_hdr, type, key, value)
      end

      # experimental
      def remove_line_at(type, pos)
        LibHTS.sam_hdr_remove_line_pos(@sam_hdr, type, pos)
      end

      def to_s
        LibHTS.sam_hdr_str(@sam_hdr)
      end

      # experimental
      def get_tid(name)
        name2tid(name)
      end

      # Add a @PG (program) line to the header
      # @param program_name [String] Name of the program
      # @param options [Hash] Key-value pairs for @PG tags (ID, PN, VN, CL, PP, etc.)
      # @return [Integer] 0 on success, -1 on failure
      #
      # This is a convenience wrapper around sam_hdr_add_pg that automatically:
      # - Generates a unique ID if the specified one clashes
      # - Manages PP (previous program) chains automatically
      #
      # @example
      #   header.add_pg("bwa", VN: "0.7.17", CL: "bwa mem ref.fa read.fq")
      #   header.add_pg("samtools", VN: "1.15", PP: "bwa")
      def add_pg(program_name, **options)
        line = build_pg_line(program_name.to_s, options)
        result = LibHTS.sam_hdr_add_lines(@sam_hdr, line, line.bytesize)
        raise "Failed to add @PG line" if result < 0

        self
      end

      private

      def build_pg_line(program_name, options)
        ordered_tags = normalize_pg_tags(program_name, options)
        "@PG\t#{ordered_tags.map { |key, value| "#{key}:#{value}" }.join("\t")}\n"
      end

      def normalize_pg_tags(program_name, options)
        existing_ids = pg_ids
        tag_map = options.each_with_object({}) do |(key, value), tags|
          string_key = key.to_s
          string_value = value.to_s
          validate_pg_tag(string_key, string_value)
          tags[string_key] = string_value
        end

        pg_id = resolve_pg_id(program_name, tag_map, existing_ids)
        validate_pg_parent(tag_map["PP"], existing_ids)

        ordered_tags = []
        ordered_tags << ["ID", pg_id]
        ordered_tags << ["PN", tag_map.fetch("PN", program_name)]
        tag_map.each do |key, value|
          next if key == "ID" || key == "PN"

          ordered_tags << [key, value]
        end
        ordered_tags
      end

      def validate_pg_tag(key, value)
        raise ArgumentError, "PG tag keys must not be empty" if key.empty?
        return unless value.include?("\t") || value.include?("\n") || value.include?("\r")

        raise ArgumentError, "PG tag values must not contain tabs or newlines"
      end

      def resolve_pg_id(program_name, tag_map, existing_ids)
        explicit_id = tag_map["ID"]
        if explicit_id
          raise ArgumentError, "PG ID already exists: #{explicit_id}" if existing_ids.include?(explicit_id)

          explicit_id
        else
          next_pg_id(program_name, existing_ids)
        end
      end

      def validate_pg_parent(parent_id, existing_ids)
        return unless parent_id
        return if existing_ids.include?(parent_id)

        raise ArgumentError, "Unknown PG parent: #{parent_id}"
      end

      def next_pg_id(program_name, existing_ids)
        candidate = program_name
        suffix = 0
        while existing_ids.include?(candidate)
          suffix += 1
          candidate = "#{program_name}.#{suffix}"
        end
        candidate
      end

      def pg_ids
        ids = []
        to_s.each_line do |line|
          next unless line.start_with?("@PG\t")

          line.chomp.split("\t")[1..].each do |field|
            key, value = field.split(":", 2)
            next unless key == "ID" && value

            ids << value
            break
          end
        end
        ids
      end

      def name2tid(name)
        LibHTS.sam_hdr_name2tid(@sam_hdr, name)
      end

      def tid2name(tid)
        LibHTS.sam_hdr_tid2name(@sam_hdr, tid)
      end

      def add_lines(str)
        LibHTS.sam_hdr_add_lines(@sam_hdr, str, 0)
      end

      def add_line(*args)
        type = args.shift
        args = args.flat_map { |arg| [:string, arg] }
        LibHTS.sam_hdr_add_line(@sam_hdr, type, *args, :pointer, FFI::Pointer::NULL)
      end

      def initialize_copy(orig)
        @sam_hdr = LibHTS.sam_hdr_dup(orig.struct)
      end
    end
  end
end
