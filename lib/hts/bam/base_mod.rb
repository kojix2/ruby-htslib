# frozen_string_literal: true

module HTS
  class Bam < Hts
    # Base modification information from MM/ML tags
    #
    # This class provides access to DNA/RNA base modifications such as methylation.
    # It wraps the htslib base modification API and provides a Ruby-friendly interface.
    #
    # @note BaseMod is a view object that references data in a Record.
    #   The state is maintained in hts_base_mod_state structure.
    class BaseMod
      include Enumerable

      class NotParsedError < StandardError; end

      attr_reader :record

      # Individual base modification information
      class Modification
        attr_reader :modified_base, :canonical_base, :strand, :qual

        # @param modified_base [Integer] Modification code as char or -ChEBI
        # @param canonical_base [Integer] Canonical base (A, C, G, T, N)
        # @param strand [Integer] 0 or 1 for +/- strand
        # @param qual [Integer] Quality (256*probability) or -1 if unknown
        def initialize(modified_base:, canonical_base:, strand:, qual:)
          @modified_base = modified_base
          @canonical_base = canonical_base
          @strand = strand
          @qual = qual
        end

        # Get modification code as character or ChEBI number as string
        # @return [String] Single character code or ChEBI number as string
        def code
          @modified_base > 0 ? @modified_base.chr : @modified_base.to_s
        end

        # Get canonical base as character
        # @return [String] Single character (A, C, G, T, N)
        def canonical
          @canonical_base.chr
        end

        # Get likelihood as a probability (0.0-1.0)
        # @return [Float, nil] Probability or nil if qual is -1
        def probability
          return nil if @qual == -1

          @qual / 256.0
        end

        # Convert to hash representation
        # @return [Hash] Hash with modification information
        def to_h
          {
            modified_base: @modified_base,
            code: code,
            canonical_base: @canonical_base,
            canonical: canonical,
            strand: @strand,
            qual: @qual,
            probability: probability
          }
        end

        # String representation
        # @return [String] String representation of the modification
        def to_s
          if @qual >= 0
            "#{canonical}->#{code}(#{probability.round(3)})"
          else
            "#{canonical}->#{code}"
          end
        end

        # Inspect string
        # @return [String] Inspect string
        def inspect
          "#<HTS::Bam::BaseMod::Modification #{self}>"
        end
      end

      # Position-specific modification information
      class Position
        attr_reader :position, :modifications

        # @param position [Integer] Position in query sequence
        # @param modifications [Array<Modification>] Array of modifications at this position
        def initialize(position, modifications)
          @position = position
          @modifications = modifications
        end

        # Check if this position has methylation
        # @return [Boolean] true if any modification is methylation ('m')
        def methylated?
          @modifications.any? { |m| m.code == "m" }
        end

        # Check if this position has hydroxymethylation
        # @return [Boolean] true if any modification is hydroxymethylation ('h')
        def hydroxymethylated?
          @modifications.any? { |m| m.code == "h" }
        end

        # Convert to hash representation
        # @return [Hash] Hash with position information
        def to_h
          {
            position: @position,
            modifications: @modifications.map(&:to_h)
          }
        end

        # String representation
        # @return [String] String representation
        def to_s
          mods_str = @modifications.map(&:to_s).join(", ")
          "pos=#{@position} [#{mods_str}]"
        end

        # Inspect string
        # @return [String] Inspect string
        def inspect
          "#<HTS::Bam::BaseMod::Position #{self}>"
        end
      end

      # Initialize a new BaseMod object
      # @param record [Record] The BAM record to extract modifications from
      # @param auto_parse [Boolean] If true, parse MM/ML lazily on first access
      def initialize(record, auto_parse: true)
        @record = record
        @state = LibHTS.hts_base_mod_state_alloc
        @closed = false
        @auto_parse = !!auto_parse
        @parsed = false
        raise Error, "Failed to allocate hts_base_mod_state" if @state.null?

        # Register finalizer to free the state
        ObjectSpace.define_finalizer(self, self.class.finalize(@state))
      end

      # Create a finalizer proc for cleanup
      # @param state [FFI::Pointer] Pointer to hts_base_mod_state
      # @return [Proc] Finalizer proc
      def self.finalize(state)
        proc { LibHTS.hts_base_mod_state_free(state) unless state.null? }
      end

      # Explicitly free the state
      # @return [void]
      def close
        return if @closed

        return unless @state && !@state.null?

        LibHTS.hts_base_mod_state_free(@state)
        @state = FFI::Pointer::NULL
        @closed = true
      end

      # Whether this object has parsed MM/ML tags already
      # @return [Boolean]
      def parsed?
        @parsed
      end

      # Ensure MM/ML have been parsed, performing lazy parse if enabled.
      # @param flags [Integer]
      # @return [void]
      def ensure_parsed!(flags = 0)
        return if @parsed

        raise NotParsedError, "BaseMod is not parsed. Call #parse first (auto_parse is disabled)." unless @auto_parse

        parse(flags)
      end

      # Parse MM and ML tags from the record
      # @param flags [Integer] Parsing flags (default: 0)
      # @return [Integer] Number of modification types found, or -1 on error
      # @raise [Error] If parsing fails
      def parse(flags = 0)
        ret = LibHTS.bam_parse_basemod2(@record.struct, @state, flags)
        raise Error, "Failed to parse base modifications" if ret < 0

        @parsed = true
        ret
      end

      # Get modification information at a specific query position
      # @param position [Integer] Query position (0-based)
      # @param max_mods [Integer] Maximum number of modifications to retrieve
      # @return [Position, nil] Position object with modifications, or nil if none
      def at_pos(position, max_mods: 10)
        ensure_parsed!

        mods_ptr = FFI::MemoryPointer.new(LibHTS::HtsBaseMod, max_mods)

        ret = LibHTS.bam_mods_at_qpos(@record.struct, position, @state,
                                      mods_ptr, max_mods)
        return nil if ret <= 0

        build_position(position, mods_ptr, [ret, max_mods].min)
      end

      # Array-style access to modifications at a position
      # @param position [Integer] Query position (0-based)
      # @return [Position, nil] Position object with modifications, or nil if none
      def [](position)
        at_pos(position)
      end

      # Iterate over all positions with modifications
      # @param max_mods [Integer] Maximum number of modifications per position
      # @yield [Position] Position object for each modified position
      # @return [Enumerator] If no block given
      def each_position(max_mods: 10)
        return enum_for(__method__, max_mods: max_mods) unless block_given?

        ensure_parsed!

        pos_ptr = FFI::MemoryPointer.new(:int)
        mods_ptr = FFI::MemoryPointer.new(LibHTS::HtsBaseMod, max_mods)

        loop do
          ret = LibHTS.bam_next_basemod(@record.struct, @state,
                                        mods_ptr, max_mods, pos_ptr)
          break if ret <= 0

          position = pos_ptr.read_int
          yield build_position(position, mods_ptr, [ret, max_mods].min)
        end
      end

      alias each each_position

      # Get list of modification types present in this record
      # @return [Array<Integer>] Array of modification codes (char code or -ChEBI)
      def modification_types
        ensure_parsed!

        ntype_ptr = FFI::MemoryPointer.new(:int)
        codes_ptr = LibHTS.bam_mods_recorded(@state, ntype_ptr)

        ntype = ntype_ptr.read_int
        return [] if ntype <= 0 || codes_ptr.null?

        codes_ptr.read_array_of_int(ntype)
      end

      alias recorded_types modification_types

      # Query information about a specific modification type by code
      # @param code [Integer, String] Modification code (char code or -ChEBI, or single char string)
      # @return [Hash, nil] Hash with canonical, strand, implicit info, or nil if not found
      def query_type(code)
        ensure_parsed!

        code = code.ord if code.is_a?(String)

        strand_ptr = FFI::MemoryPointer.new(:int)
        implicit_ptr = FFI::MemoryPointer.new(:int)
        canonical_ptr = FFI::MemoryPointer.new(:char, 1)

        ret = LibHTS.bam_mods_query_type(@state, code, strand_ptr,
                                         implicit_ptr, canonical_ptr)
        return nil if ret < 0

        {
          canonical: canonical_ptr.read_char.chr,
          strand: strand_ptr.read_int,
          implicit: implicit_ptr.read_int != 0
        }
      end

      # Query information about i-th modification type
      # @param index [Integer] Modification type index (0-based)
      # @return [Hash, nil] Hash with code, canonical, strand, implicit info
      def query_type_at(index)
        ensure_parsed!

        strand_ptr = FFI::MemoryPointer.new(:int)
        implicit_ptr = FFI::MemoryPointer.new(:int)
        canonical_ptr = FFI::MemoryPointer.new(:char, 1)

        ret = LibHTS.bam_mods_queryi(@state, index, strand_ptr,
                                     implicit_ptr, canonical_ptr)
        return nil if ret < 0

        types = modification_types
        {
          code: types[index],
          canonical: canonical_ptr.read_char.chr,
          strand: strand_ptr.read_int,
          implicit: implicit_ptr.read_int != 0
        }
      end

      # Get all modifications as an array
      # @return [Array<Position>] Array of all positions with modifications
      def to_a
        each_position.to_a
      end

      # String representation for debugging
      # @return [String] String representation
      def to_s
        return "#<HTS::Bam::BaseMod (not parsed)>" unless @parsed

        mods = []
        each_position do |pos|
          mods << pos.to_s
        end
        "#<HTS::Bam::BaseMod #{mods.join(' ')}>"
      end

      # Inspect string
      # @return [String] Inspect string
      def inspect
        to_s
      end

      private

      # Build Position object from hts_base_mod array
      # @param position [Integer] Query position
      # @param mods_ptr [FFI::Pointer] Pointer to array of HtsBaseMod structures
      # @param n_mods [Integer] Number of modifications
      # @return [Position] Position object
      def build_position(position, mods_ptr, n_mods)
        modifications = []

        n_mods.times do |i|
          mod_struct = LibHTS::HtsBaseMod.new(mods_ptr + i * LibHTS::HtsBaseMod.size)

          modifications << Modification.new(
            modified_base: mod_struct[:modified_base],
            canonical_base: mod_struct[:canonical_base],
            strand: mod_struct[:strand],
            qual: mod_struct[:qual]
          )
        end

        Position.new(position, modifications)
      end
    end
  end
end
