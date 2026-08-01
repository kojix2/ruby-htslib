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
        @state = Native::BaseModHandle.open(record.__send__(:native_handle))
        @closed = false
        @auto_parse = !!auto_parse
        @parsed = false
      end

      # Explicitly free the state
      # @return [void]
      def close
        return if @closed

        @state.close
        @state = nil
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
        ret = @state.parse(flags)
        raise Error, "Failed to parse base modifications" if ret < 0

        @parsed = true
        ret
      end

      # Get modification information at a specific query position
      # @param position [Integer] Query position (0-based)
      # @param max_mods [Integer] Maximum number of modifications to retrieve
      # @return [Position, nil] Position object with modifications, or nil if none
      def at_pos(position, max_mods: 10)
        # Reset state to ensure deterministic results even after prior iteration
        parsed? ? parse : ensure_parsed!

        values = @state.at(position, max_mods)
        return nil unless values

        build_position(position, values)
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

        current_position = nil
        modifications = []
        each_raw(max_mods: max_mods) do |position, canonical, modified, strand, qual|
          if current_position && position != current_position
            yield Position.new(current_position, modifications)
            modifications = []
          end
          current_position = position
          modifications << Modification.new(
            modified_base: modified, canonical_base: canonical,
            strand: strand, qual: qual
          )
        end
        yield Position.new(current_position, modifications) if current_position
        self
      end

      alias each each_position

      # Iterate primitive modification values without Position/Modification
      # object allocation.
      def each_raw(max_mods: 10)
        return enum_for(__method__, max_mods: max_mods) unless block_given?

        parsed? ? parse : ensure_parsed!
        @state.each_raw(max_mods) { |*values| yield(*values) }
        self
      end

      # Get list of modification types present in this record
      # @return [Array<Integer>] Array of modification codes (char code or -ChEBI)
      def modification_types
        ensure_parsed!

        @state.types
      end

      alias recorded_types modification_types

      # Query information about a specific modification type by code
      # @param code [Integer, String] Modification code (char code or -ChEBI, or single char string)
      # @return [Hash, nil] Hash with canonical, strand, implicit info, or nil if not found
      def query_type(code)
        ensure_parsed!

        code = code.ord if code.is_a?(String)

        @state.query(code)
      end

      # Query information about i-th modification type
      # @param index [Integer] Modification type index (0-based)
      # @return [Hash, nil] Hash with code, canonical, strand, implicit info
      def query_type_at(index)
        ensure_parsed!

        @state.query_at(index)
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
      # @param values [Array<Array>] Native modification values
      # @return [Position] Position object
      def build_position(position, values)
        modifications = values.map do |canonical, modified, strand, qual|
          Modification.new(modified_base: modified, canonical_base: canonical, strand:, qual:)
        end

        Position.new(position, modifications)
      end
    end
  end
end
