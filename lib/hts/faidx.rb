# frozen_string_literal: true

require_relative "../htslib"
require_relative "faidx/sequence"

module HTS
  class Faidx
    include Enumerable

    attr_reader :file_name

    def self.open(*args, **kw)
      file = new(*args, **kw) # do not yield
      return file unless block_given?

      begin
        yield file
      ensure
        file.close
      end
      file
    end

    def initialize(file_name)
      raise ArgumentError, "HTS::Faidx.new() does not take block; Please use HTS::Faidx.open() instead" if block_given?

      @file_name = file_name.freeze
      @fai = case File.extname(@file_name)
             when ".fq", ".fastq"
               LibHTS.fai_load_format(@file_name, 2)
             else
               LibHTS.fai_load(@file_name)
             end

      raise Errno::ENOENT, "Failed to open #{@file_name}" if @fai.null?
    end

    def struct
      @fai
    end

    def close
      return if closed?

      LibHTS.fai_destroy(@fai)
      @fai = nil
    end

    def closed?
      @fai.nil? || @fai.null?
    end

    def file_format
      check_closed
      @fai[:format]
    end

    # Iterate over each sequence in the index.
    # @yield [Sequence] each sequence object
    # @return [Enumerator] if no block given
    def each
      return to_enum(__method__) unless block_given?

      check_closed
      names.each { |name| yield self[name] }
    end

    # the number of sequences in the index.
    # @return [Integer] the number of sequences
    def length
      check_closed
      LibHTS.faidx_nseq(@fai)
    end
    alias size length

    # Return the list of sequence names in the index.
    # @return [Array<String>] sequence names
    def names
      check_closed
      Array.new(length) { |i| LibHTS.faidx_iseq(@fai, i) }
    end

    alias keys names

    # Check if a sequence exists in the index.
    # @param key [String, Symbol] sequence name
    # @return [Boolean] true if the sequence exists
    def has_key?(key)
      check_closed
      raise ArgumentError, "Expect chrom to be String or Symbol" unless key.is_a?(String) || key.is_a?(Symbol)

      key = key.to_s
      case LibHTS.faidx_has_seq(@fai, key)
      when 1 then true
      when 0 then false
      else raise HTS::Error, "Unexpected return value from faidx_has_seq"
      end
    end

    # Get a Sequence object by name or index.
    # @param name [String, Symbol, Integer] sequence name or index
    # @return [Sequence] the sequence object
    # @raise [ArgumentError] if the sequence does not exist
    def [](name)
      check_closed
      name = LibHTS.faidx_iseq(@fai, name) if name.is_a?(Integer)
      Sequence.new(self, name)
    end

    # Return the length of the requested chromosome.
    # @param chrom [String, Symbol] chromosome name
    # @return [Integer] sequence length
    # @raise [ArgumentError] if the sequence does not exist
    def seq_len(chrom)
      check_closed
      raise ArgumentError, "Expect chrom to be String or Symbol" unless chrom.is_a?(String) || chrom.is_a?(Symbol)

      chrom = chrom.to_s
      result = LibHTS.faidx_seq_len(@fai, chrom)
      raise ArgumentError, "Sequence not found: #{chrom}" if result == -1

      result
    end

    # @overload fetch_seq(name)
    #   Fetch the sequence as a String.
    #   @param name [String, Symbol] chr1:0-10
    #   @return [String] the sequence
    # @overload fetch_seq(name, start, stop)
    #   Fetch the sequence as a String.
    #   @param name [String, Symbol] the name of the chromosome
    #   @param start [Integer] the start position of the sequence (0-based)
    #   @param stop [Integer] the end position of the sequence (0-based)
    #   @return [String] the sequence
    def fetch_seq(name, start = nil, stop = nil)
      check_closed
      name = name.to_s
      rlen = FFI::MemoryPointer.new(:int)

      if start.nil? && stop.nil?
        result = LibHTS.fai_fetch64(@fai, name, rlen)
      else
        validate_range!(name, start, stop)
        result = LibHTS.faidx_fetch_seq64(@fai, name, start, stop, rlen)
      end

      case rlen.read_int
      when -2 then raise ArgumentError, "Invalid chromosome name: #{name}"
      when -1 then raise HTS::Error, "Error fetching sequence: #{name}:#{start}-#{stop}"
      end

      result
    end

    alias seq fetch_seq

    # @overload fetch_qual(name)
    #   Fetch the quality string.
    #   @param name [String, Symbol] sequence name
    #   @return [String] the quality string
    # @overload fetch_qual(name, start, stop)
    #   Fetch the quality string.
    #   @param name [String, Symbol] the name of the chromosome
    #   @param start [Integer] the start position of the sequence (0-based)
    #   @param stop [Integer] the end position of the sequence (0-based)
    #   @return [String] the quality string
    def fetch_qual(name, start = nil, stop = nil)
      check_closed
      name = name.to_s
      rlen = FFI::MemoryPointer.new(:int)

      if start.nil? && stop.nil?
        result = LibHTS.fai_fetchqual64(@fai, name, rlen)
      else
        validate_range!(name, start, stop)
        result = LibHTS.faidx_fetch_qual64(@fai, name, start, stop, rlen)
      end

      case rlen.read_int
      when -2 then raise ArgumentError, "Invalid chromosome name: #{name}"
      when -1 then raise HTS::Error, "Error fetching quality: #{name}:#{start}-#{stop}"
      end

      result
    end

    alias qual fetch_qual

    private

    def check_closed
      raise IOError, "closed Faidx" if closed?
    end

    # Validate range parameters.
    # @param name [String] sequence name
    # @param start [Integer] start position (0-based)
    # @param stop [Integer] stop position (0-based)
    # @raise [ArgumentError] if range is invalid
    def validate_range!(name, start, stop)
      raise ArgumentError, "Expect start to be >= 0" if start < 0
      raise ArgumentError, "Expect stop to be >= 0" if stop < 0
      raise ArgumentError, "Expect start to be <= stop" if start > stop

      len = seq_len(name)
      raise ArgumentError, "Sequence not found: #{name}" if len.nil?
      raise ArgumentError, "Expect stop to be < seq_len (#{len})" if stop >= len
    end
  end
end
