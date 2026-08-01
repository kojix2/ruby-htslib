# frozen_string_literal: true

require_relative "flag"
require_relative "cigar"
require_relative "auxi"

module HTS
  class Bam < Hts
    class Record
      SEQ_NT16_STR = "=ACMGRSVTWYHKDBN"
      UNSET = Object.new.freeze
      private_constant :UNSET
      attr_reader :header

      # Build a BAM record from Ruby values. Coordinates are zero-based, matching
      # the rest of this API. +qualities+ is an Array of numeric Phred scores;
      # use +quality_string+ for a FASTQ/SAM-style Phred+33 String.
      def initialize(header, native_record = nil, qname: "*", flag: 0, tid: nil, chrom: nil,
                     pos: -1, mapq: 0, cigar: nil, mtid: nil, mate_chrom: nil,
                     mate_pos: -1, insert_size: 0, seq: UNSET, sequence: UNSET,
                     qual: UNSET, qualities: UNSET, quality_string: UNSET, aux: nil)
        @native = native_record || Native::BamRecordHandle.create
        @header = header
        return if native_record

        sequence = normalize_sequence(seq, sequence)
        qualities = normalize_qualities(qual, qualities, quality_string, sequence.bytesize)
        cigar_values = normalize_cigar(cigar)
        validate_cigar_length!(cigar_values, sequence)

        @native.replace(
          normalize_qname(qname), normalize_flag(flag), resolve_tid(tid, chrom, "chrom"),
          normalize_position(pos, "pos"), normalize_mapq(mapq), cigar_values,
          resolve_tid(mtid, mate_chrom, "mate_chrom"), normalize_position(mate_pos, "mate_pos"),
          Integer(insert_size), sequence, qualities
        )
        assign_aux(aux) if aux
      end

      def qname = @native.qname
      def qname=(name)
        @native.qname = name
      end
      def tid = core_get(:tid)
      def tid=(value)
        core_set(:tid, value)
      end
      def mtid = core_get(:mtid)
      def mtid=(value)
        core_set(:mtid, value)
      end
      def pos = core_get(:pos)
      def pos=(value)
        core_set(:pos, value)
      end
      def mate_pos = core_get(:mpos)
      def mate_pos=(value)
        core_set(:mpos, value)
      end
      alias mpos mate_pos
      alias mpos= mate_pos=
      def bin = core_get(:bin)
      def bin=(value)
        core_set(:bin, value)
      end
      def endpos = @native.endpos

      def chrom
        return "" if tid == -1

        @header.__send__(:native_handle).target_name(tid)
      end
      alias contig chrom
      def chrom=(name)
        self.tid = resolve_tid(nil, name, "chrom")
      end
      alias contig= chrom=

      def mate_chrom
        return "" if mtid == -1

        @header.__send__(:native_handle).target_name(mtid)
      end
      alias mate_contig mate_chrom
      def mate_chrom=(name)
        self.mtid = resolve_tid(nil, name, "mate_chrom")
      end
      alias mate_contig= mate_chrom=

      def strand = reverse? ? "-" : "+"
      def mate_strand = mate_reverse? ? "-" : "+"
      def insert_size = core_get(:isize)
      def insert_size=(value)
        core_set(:isize, value)
      end
      alias isize insert_size
      alias isize= insert_size=
      def mapq = core_get(:mapq)
      def mapq=(value)
        core_set(:mapq, value)
      end

      def cigar = Cigar.new(self)
      def cigar=(value)
        raise ArgumentError, "cigar must be a String or Bam::Cigar" unless value.is_a?(String) || value.is_a?(Cigar)

        @native.cigar = value.to_s
      end
      def qlen = @native.qlen
      def rlen = @native.rlen
      def seq = @native.sequence
      alias sequence seq

      def each_base
        return to_enum(__method__) unless block_given?

        seq.each_char { |base| yield base }
        self
      end

      def each_base_code
        return to_enum(__method__) unless block_given?

        @native.sequence_codes.each { |code| yield code }
        self
      end

      def len = core_get(:length)

      def base(index)
        index += len if index.negative?
        code = @native.base_code(index)
        code ? SEQ_NT16_STR[code] : "."
      end
      alias base_at base

      def qual = @native.qualities
      def qual_string = @native.quality_string

      def each_qual
        return to_enum(__method__) unless block_given?

        @native.qualities.each { |quality| yield quality }
        self
      end

      def base_qual(index)
        index += len if index.negative?
        @native.quality_at(index) || 0
      end
      alias qual_at base_qual

      def flag = Flag.new(flag_value)
      def flag_value = core_get(:flag)
      def flag=(value)
        case value
        when Integer then core_set(:flag, value)
        when Flag then core_set(:flag, value.value)
        else raise "Invalid flag type: #{value.class}"
        end
      end

      def aux(key = nil)
        accessor = (@aux_accessor ||= Aux.new(self))
        key ? accessor.get(key) : accessor
      end

      def base_mod(auto_parse: true) = BaseMod.new(self, auto_parse:)

      def each_base_mod_raw(max_mods: 10, &block)
        return enum_for(__method__, max_mods:) unless block

        mods = BaseMod.new(self)
        begin
          mods.each_raw(max_mods:, &block)
        ensure
          mods.close
        end
        self
      end

      Flag::TABLE.each do |method_name, mask|
        define_method(method_name) { (flag_value & mask) != 0 }
      end

      def each_cigar_raw
        return to_enum(__method__) unless block_given?

        @native.cigar_values.each { |encoded| yield encoded & 15, encoded >> 4 }
        self
      end

      def to_s = @native.format(@header.__send__(:native_handle))

      private

      def native_handle = @native
      def core_get(field) = @native.core_get(field)
      def core_set(field, value) = @native.core_set(field, value)

      def normalize_qname(value)
        value = value.to_s
        raise ArgumentError, "qname must not contain NUL bytes" if value.include?("\0")

        value
      end

      def normalize_flag(value)
        integer = value.is_a?(Flag) ? value.value : Integer(value)
        raise RangeError, "flag must be between 0 and 65535" unless integer.between?(0, 65_535)

        integer
      end

      def normalize_mapq(value)
        integer = Integer(value)
        raise RangeError, "mapq must be between 0 and 255" unless integer.between?(0, 255)

        integer
      end

      def normalize_position(value, name)
        integer = Integer(value)
        raise RangeError, "#{name} must be -1 or greater" if integer < -1

        integer
      end

      def resolve_tid(numeric, name, label)
        if !numeric.nil? && !name.nil?
          raise ArgumentError, "specify either #{label} or its numeric id, not both"
        end

        id = if name.nil?
               numeric.nil? ? -1 : Integer(numeric)
             elsif name.to_s == "*"
               -1
             else
               @header.get_tid(name.to_s)
             end
        raise ArgumentError, "unknown reference #{name.inspect}" if !name.nil? && id.negative? && name.to_s != "*"
        raise RangeError, "reference id must be -1 or greater" if id < -1
        raise RangeError, "reference id #{id} is not present in the header" if id >= @header.target_count

        id
      end

      def normalize_sequence(short, long)
        raise ArgumentError, "specify either seq or sequence, not both" unless short.equal?(UNSET) || long.equal?(UNSET)

        value = long.equal?(UNSET) ? short : long
        value = "" if value.equal?(UNSET) || value.nil? || value == "*"
        value = value.to_s
        unless /\A[=ACMGRSVTWYHKDBNacmgrsvtwyhkdbn]*\z/.match?(value)
          raise ArgumentError, "sequence contains an invalid BAM base"
        end

        value
      end

      def normalize_qualities(short, long, string, sequence_length)
        supplied = [short, long, string].count { |value| !value.equal?(UNSET) }
        raise ArgumentError, "specify only one of qual, qualities, or quality_string" if supplied > 1

        value = if !string.equal?(UNSET)
                  quality_string_to_bytes(string)
                elsif !long.equal?(UNSET)
                  quality_values_to_bytes(long)
                elsif !short.equal?(UNSET)
                  short.is_a?(String) ? quality_string_to_bytes(short) : quality_values_to_bytes(short)
                end
        if value && value.bytesize != sequence_length
          raise ArgumentError, "qualities length must match sequence length"
        end

        value
      end

      def quality_values_to_bytes(values)
        return nil if values.nil?

        array = Array(values).map { |value| Integer(value) }
        invalid = array.find { |value| !value.between?(0, 93) }
        raise RangeError, "quality scores must be between 0 and 93" if invalid

        array.pack("C*")
      end

      def quality_string_to_bytes(value)
        return nil if value.nil? || value == "*"

        string = value.to_s
        unless string.ascii_only? && string.bytes.all? { |byte| byte.between?(33, 126) }
          raise ArgumentError, "quality_string must contain only Phred+33 characters from ! to ~"
        end

        string.bytes.map { |byte| byte - 33 }.pack("C*")
      end

      def normalize_cigar(value)
        return [] if value.nil? || value.to_s == "*"

        case value
        when String then Cigar.parse(value).array
        when Cigar then value.array.dup
        else raise ArgumentError, "cigar must be a String or Bam::Cigar"
        end
      end

      def validate_cigar_length!(values, sequence)
        query_length = Native.cigar_qlen(values)
        return if values.empty? || query_length == sequence.bytesize

        raise ArgumentError, "CIGAR query length #{query_length} does not match sequence length #{sequence.bytesize}"
      end

      def assign_aux(values)
        unless values.respond_to?(:each_pair)
          raise ArgumentError, "aux must be a Hash-like object"
        end

        values.each_pair { |key, value| aux()[key.to_s] = value }
      end

      def initialize_copy(original)
        super
        @header = original.header
        @native = original.__send__(:native_handle).duplicate
        @aux_accessor = nil
      end
    end
  end
end
