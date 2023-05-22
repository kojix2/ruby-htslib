# frozen_string_literal: true

require_relative "header_record"

module HTS
  class Bam < Hts
    # A class for working with alignment header.
    class Header
      def self.parse(str)
        new(LibHTS.sam_hdr_parse(str.size, str))
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

      def target_count
        # FIXME: sam_hdr_nref
        @sam_hdr[:n_targets]
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
        r = LibHTS.sam_hdr_find_line_id(@sam_hdr, type, key, value, ks)
        r == 0 ? ks[:s] : nil
      end

      # experimental
      def find_line_at(type, pos)
        ks = LibHTS::KString.new
        r = LibHTS.sam_hdr_find_line_pos(@sam_hdr, type, pos, ks)
        r == 0 ? ks[:s] : nil
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

      def name2tid(name)
        LibHTS.sam_hdr_name2tid(@sam_hdr, name)
      end

      def tid2name(tid)
        LibHTS.sam_hdr_tid2name(@sam_hdr, tid)
      end

      private

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
