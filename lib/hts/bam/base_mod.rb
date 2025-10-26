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
        attr_reader :code, :canonical, :modified, :likelihood

        # @param code [String] Modification code (e.g., 'm', 'h')
        # @param canonical [String] Original base (e.g., 'C', 'A')
        # @param modified [String, nil] Modified base name (optional)
        # @param likelihood [Integer, nil] Likelihood value 0-255 (optional)
        def initialize(code:, canonical:, modified: nil, likelihood: nil)
          @code = code
          @canonical = canonical
          @modified = modified
          @likelihood = likelihood
        end

        # Get likelihood as a probability (0.0-1.0)
        # @return [Float, nil] Probability or nil if likelihood is not set
        def probability
          return nil unless @likelihood

          @likelihood / 255.0
        end

        # Convert to hash representation
        # @return [Hash] Hash with modification information
        def to_h
          {
            code: @code,
            canonical: @canonical,
            modified: @modified,
            likelihood: @likelihood
          }
        end

        # String representation
        # @return [String] String representation of the modification
        def to_s
          if @likelihood
            "#{@canonical}->#{@code}(#{probability.round(3)})"
          else
            "#{@canonical}->#{@code}"
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
        attr_reader :position, :strand, :modifications

        # @param position [Integer] Position in query sequence
        # @param strand [Integer] Strand (0 or 1)
        # @param modifications [Array<Modification>] Array of modifications at this position
        def initialize(position, strand, modifications)
          @position = position
          @strand = strand
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
            strand: @strand,
            modifications: @modifications.map(&:to_h)
          }
        end

        # String representation
        # @return [String] String representation
        def to_s
          mods_str = @modifications.map(&:to_s).join(", ")
          "pos=#{@position} strand=#{@strand} [#{mods_str}]"
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
      # @return [Position, nil] Position object with modifications, or nil if none
      def at_pos(position)
        ensure_parsed!
        mods_ptr = FFI::MemoryPointer.new(:pointer)
        n_mods = FFI::MemoryPointer.new(:int)

        ret = LibHTS.bam_mods_at_qpos(@record.struct, position, @state, mods_ptr, n_mods)
        return nil if ret < 0

        build_position_info(position, ret, mods_ptr, n_mods.read_int)
      end

      # Array-style access to modifications at a position
      # @param position [Integer] Query position (0-based)
      # @return [Position, nil] Position object with modifications, or nil if none
      def [](position)
        at_pos(position)
      end

      # Iterate over all positions with modifications
      # @yield [Position] Position object for each modified position
      # @return [Enumerator] If no block given
      def each_position
        return enum_for(__method__) unless block_given?

        ensure_parsed!
        position = FFI::MemoryPointer.new(:int)
        mods_ptr = FFI::MemoryPointer.new(:pointer)
        n_mods = FFI::MemoryPointer.new(:int)

        loop do
          ret = LibHTS.bam_next_basemod(@record.struct, @state, mods_ptr, n_mods, position)
          break if ret < 0

          yield build_position_info(position.read_int, ret, mods_ptr, n_mods.read_int)
        end
      end

      alias each each_position

      # Get list of modification types present in this record
      # @return [Array<String>] Array of modification code characters
      def modification_types
        ensure_parsed!
        codes_ptr = FFI::MemoryPointer.new(:pointer)
        n_types = LibHTS.bam_mods_recorded(@state, codes_ptr)
        return [] if n_types <= 0

        codes_ptr.read_pointer.read_string(n_types).chars
      end

      alias recorded_types modification_types

      # Query information about a specific modification type
      # @param code_char [String] Modification code character
      # @return [Hash, nil] Hash with canonical, strand, implicit info, or nil if not found
      def query_type(code_char)
        ensure_parsed!
        strand = FFI::MemoryPointer.new(:int)
        implicit = FFI::MemoryPointer.new(:int)
        canonical = FFI::MemoryPointer.new(:char, 8)

        ret = LibHTS.bam_mods_query_type(@state, code_char.ord, strand, implicit, canonical)
        return nil if ret < 0

        {
          canonical: canonical.read_string,
          strand: strand.read_int,
          implicit: implicit.read_int != 0
        }
      end

      # Get all modifications as an array
      # @return [Array<Position>] Array of all positions with modifications
      def to_a
        ensure_parsed!
        each_position.to_a
      end

      # String representation for debugging
      # @return [String] String representation
      def to_s
        ensure_parsed!
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

      # Build Position object from C API results
      # @param position [Integer] Query position
      # @param strand [Integer] Strand information
      # @param mods_ptr [FFI::Pointer] Pointer to modifications array
      # @param n_mods [Integer] Number of modifications
      # @return [Position] Position object
      def build_position_info(position, strand, _mods_ptr, n_mods)
        modifications = []
        # mods_array = mods_ptr.read_pointer # Would be used for parsing mod structures

        # Get canonical base information
        type_info = nil
        recorded = modification_types
        recorded.each do |code|
          info = query_type(code)
          if info
            type_info = info
            break
          end
        end

        n_mods.times do |i|
          # Each modification is represented as a hts_base_mod structure
          # We need to read the modification code and likelihood
          # The structure layout depends on htslib version, so we'll use the query functions

          # For now, create a basic Modification object
          # In a full implementation, we'd parse the actual mod data from mods_array
          # mod_data = mods_array[i * 8, 8] # Would need proper structure parsing

          modifications << Modification.new(
            code: recorded[i] || "?",
            canonical: type_info ? type_info[:canonical] : "N",
            likelihood: nil # Would need to extract from proper structure
          )
        end

        Position.new(position, strand, modifications)
      end
    end
  end
end
