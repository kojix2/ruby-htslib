# frozen_string_literal: true

require_relative "../htslib"
require_relative "faidx/sequence"

module HTS
  class Faidx
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
      if block_given?
        message = "HTS::Faidx.new() dose not take block; Please use HTS::Faidx.open() instead"
        raise message
      end

      @file_name = file_name
      @fai = LibHTS.fai_load(@file_name)

      raise Errno::ENOENT, "Failed to open #{@file_name}" if @fai.null?
    end

    def struct
      @fai
    end

    def close
      LibHTS.fai_destroy(@fai)
    end

    # the number of sequences in the index.
    def length
      LibHTS.faidx_nseq(@fai)
    end
    alias size length

    # return the length of the requested chromosome.
    def names
      Array.new(length) { |i| LibHTS.faidx_iseq(@fai, i) }
    end

    alias keys names

    def [](name)
      name = names[name] if name.is_a?(Integer)
      Sequence.new(self, name)
    end

    # return the length of the requested chromosome.
    def seq_len(chrom)
      raise ArgumentError, "Expect chrom to be String or Symbol" unless chrom.is_a?(String) || chrom.is_a?(Symbol)

      chrom = chrom.to_s
      result = LibHTS.faidx_seq_len(@fai, chrom)
      result == -1 ? nil : result
    end

    # @overload fetch(name)
    #   Fetch the sequence as a String.
    #   @param name [String] chr1:0-10
    # @overload fetch(name, start, stop)
    #   Fetch the sequence as a String.
    #   @param name [String] the name of the chromosome
    #   @param start [Integer] the start position of the sequence (0-based)
    #   @param stop [Integer] the end position of the sequence (0-based)
    #   @return [String] the sequence

    def seq(name, start = nil, stop = nil)
      name = name.to_s
      rlen = FFI::MemoryPointer.new(:int)

      if start.nil? && stop.nil?
        result = LibHTS.fai_fetch(@fai, name, rlen)
      else
        start < 0    && raise(ArgumentError, "Expect start to be >= 0")
        stop  < 0    && raise(ArgumentError, "Expect stop to be >= 0")
        start > stop && raise(ArgumentError, "Expect start to be <= stop")

        result = LibHTS.faidx_fetch_seq(@fai, name, start, stop, rlen)
      end

      case rlen.read_int
      when -2 then raise "Invalid chromosome name: #{name}"
      when -1 then raise "Error fetching sequence: #{name}:#{start}-#{stop}"
      end

      result
    end
  end
end
