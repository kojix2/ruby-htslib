# frozen_string_literal: true

require_relative "header_record"

module HTS
  class Bam < Hts
    # A class for working with alignment header.
    class Header
      HD_TAG_MAP = {
        version: "VN",
        sort_order: "SO",
        group_order: "GO",
        subsorting: "SS"
      }.freeze

      SQ_TAG_MAP = {
        name: "SN",
        length: "LN",
        assembly: "AS",
        md5: "M5",
        species: "SP",
        uri: "UR",
        alt_names: "AN"
      }.freeze

      RG_TAG_MAP = {
        id: "ID",
        sample: "SM",
        library: "LB",
        platform: "PL",
        platform_unit: "PU",
        center: "CN",
        description: "DS",
        date: "DT",
        flow_order: "FO",
        key_sequence: "KS",
        program: "PG",
        insert_size: "PI",
        molecule_topology: "PM"
      }.freeze

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

      def append(line)
        add_lines(ensure_newline(line.to_s))
        self
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

      def find_tag(type, id_key, id_value, key)
        ks = LibHTS::KString.new
        begin
          r = LibHTS.sam_hdr_find_tag_id(@sam_hdr, type, id_key, id_value, key, ks)
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

      def delete_line(type, key = nil, value = nil)
        LibHTS.sam_hdr_remove_line_id(@sam_hdr, type, key, value).zero?
      end

      def delete_tag(type, id_key, id_value, key)
        LibHTS.sam_hdr_remove_tag_id(@sam_hdr, type, id_key, id_value, key) == 1
      end

      def count_lines(type)
        LibHTS.sam_hdr_count_lines(@sam_hdr, type)
      end

      def line_index(type, key)
        LibHTS.sam_hdr_line_index(@sam_hdr, type, key)
      end

      def line_name(type, pos)
        LibHTS.sam_hdr_line_name(@sam_hdr, type, pos)
      end

      def to_s
        LibHTS.sam_hdr_str(@sam_hdr)
      end

      # experimental
      def get_tid(name)
        name2tid(name)
      end

      def update_hd(**tags)
        pairs = merge_sam_pairs(find_line_pairs("HD", nil, nil), normalize_hd_tags(tags))
        replace_sam_line("HD", nil, nil, pairs, %w[VN SO GO SS])
        self
      end

      def add_sq(name, length:, **tags)
        pairs = [["SN", name.to_s], ["LN", length.to_s]]
        pairs.concat normalize_sq_tags(tags)
        add_structured_sam_line("SQ", pairs, %w[SN LN AS M5 SP UR AN])
        self
      end

      def update_sq(name, **tags)
        pairs = merge_identified_sam_line("SQ", "SN", name.to_s, normalize_sq_tags(tags), protected_keys: ["SN"])
        replace_sam_line("SQ", "SN", name.to_s, pairs, %w[SN LN AS M5 SP UR AN])
        self
      end

      def remove_sq(name)
        delete_line("SQ", "SN", name.to_s)
      end

      def add_rg(id, **tags)
        pairs = [["ID", id.to_s]]
        pairs.concat normalize_rg_tags(tags)
        add_structured_sam_line("RG", pairs, %w[ID SM LB PL PU CN DS DT FO KS PG PI PM])
        self
      end

      def update_rg(id, **tags)
        pairs = merge_identified_sam_line("RG", "ID", id.to_s, normalize_rg_tags(tags), protected_keys: ["ID"])
        replace_sam_line("RG", "ID", id.to_s, pairs, %w[ID SM LB PL PU CN DS DT FO KS PG PI PM])
        self
      end

      def remove_rg(id)
        delete_line("RG", "ID", id.to_s)
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

      def normalize_hd_tags(tags)
        normalize_sam_tags(tags, HD_TAG_MAP)
      end

      def normalize_sq_tags(tags)
        normalize_sam_tags(tags, SQ_TAG_MAP)
      end

      def normalize_rg_tags(tags)
        normalize_sam_tags(tags, RG_TAG_MAP)
      end

      def normalize_sam_tags(tags, tag_map)
        tags.each_with_object([]) do |(key, value), pairs|
          sam_key = tag_map.fetch(key.to_sym, key.to_s.upcase)
          sam_value = value.is_a?(Array) ? value.join(",") : value.to_s
          raise ArgumentError, "Header tag keys must not be empty" if sam_key.empty?
          if sam_value.include?("\t") || sam_value.include?("\n") || sam_value.include?("\r")
            raise ArgumentError, "Header tag values must not contain tabs or newlines"
          end

          pairs << [sam_key, sam_value]
        end
      end

      def parse_sam_pairs(line)
        line.to_s.chomp.split("\t")[1..].to_a.map do |field|
          key, value = field.split(":", 2)
          [key, value.to_s]
        end
      end

      def find_line_pairs(type, id_key, id_value)
        line = find_line(type, id_key, id_value)
        line ? parse_sam_pairs(line) : []
      end

      def merge_identified_sam_line(type, id_key, id_value, updates, protected_keys: [])
        line = find_line(type, id_key, id_value)
        raise ArgumentError, "Header line not found: @#{type} #{id_key}:#{id_value}" unless line

        merge_sam_pairs(parse_sam_pairs(line), updates, protected_keys:)
      end

      def merge_sam_pairs(existing_pairs, updates, protected_keys: [])
        pairs = existing_pairs.map(&:dup)
        updates.each do |key, value|
          if protected_keys.include?(key)
            raise ArgumentError, "Header tag #{key} cannot be updated" unless existing_pairs.none? { |pair| pair[0] == key && pair[1] == value }

            next
          end

          index = pairs.index { |pair| pair[0] == key }
          if index
            pairs[index] = [key, value]
          else
            pairs << [key, value]
          end
        end
        pairs
      end

      def add_structured_sam_line(type, pairs, preferred_order)
        append(build_sam_line(type, pairs, preferred_order))
      end

      def replace_sam_line(type, id_key, id_value, pairs, preferred_order)
        delete_line(type, id_key, id_value)
        append(build_sam_line(type, pairs, preferred_order))
      end

      def build_sam_line(type, pairs, preferred_order)
        ordered_pairs = preferred_order.filter_map do |key|
          pairs.find { |pair| pair[0] == key }
        end
        pairs.each do |pair|
          ordered_pairs << pair unless preferred_order.include?(pair[0])
        end

        "@#{type}\t#{ordered_pairs.map { |key, value| "#{key}:#{value}" }.join("\t")}\n"
      end

      def ensure_newline(text)
        text.end_with?("\n") ? text : "#{text}\n"
      end

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
