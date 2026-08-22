# frozen_string_literal: true

require_relative "native"

module HTS
  class Faidx
    class OpenError < HTS::Error; end

    attr_reader :file_name, :format

    def self.open(file_name, format: :auto, auto_build: true)
      file = new(file_name, format:, auto_build:)
      return file unless block_given?

      begin
        yield file
      ensure
        file.close
      end
      file
    end

    def self.build_index(file_name, fai_path = nil, gzi_path = nil)
      return if Native::FaidxHandle.build(file_name, fai_path, gzi_path).zero?

      raise HTS::Error, "Failed to build faidx index for #{file_name}"
    end

    def initialize(file_name, format: :auto, auto_build: true)
      raise ArgumentError, "HTS::Faidx.new() does not take block; Please use HTS::Faidx.open() instead" if block_given?

      @file_name = file_name.freeze
      @format = resolve_format(@file_name, format)
      @native = Native::FaidxHandle.open(@file_name, @format == :fastq ? 1 : 0, auto_build)
    rescue Errno::ENOENT
      raise Errno::ENOENT, "Failed to open #{@file_name}"
    end

    def close = @native&.close
    def closed? = @native.nil? || @native.closed?
    def size = native.size
    alias length size
    def names = native.names

    def has_seq?(key)
      raise ArgumentError, "Expect chrom to be String or Symbol" unless key.is_a?(String) || key.is_a?(Symbol)

      native.has_seq?(key.to_s)
    end

    def seq_len(chrom)
      raise ArgumentError, "Expect chrom to be String or Symbol" unless chrom.is_a?(String) || chrom.is_a?(Symbol)

      chrom = chrom.to_s
      result = native.seq_len(chrom)
      raise ArgumentError, "Sequence not found: #{chrom}" if result == -1

      result
    end

    def fetch_seq(name, start = nil, stop = nil)
      name = name.to_s
      if start.nil? && stop.nil?
        len = seq_len(name)
        return "" if len.zero?

        start = 0
        stop = len - 1
      else
        validate_range!(name, start, stop)
      end
      fetch_result(native.fetch_seq(name, start, stop), "sequence", name, start, stop)
    end

    def fetch_qual(name, start = nil, stop = nil)
      native
      raise HTS::Error, "Quality is only available for FASTQ indexes" unless format == :fastq

      name = name.to_s
      if start.nil? && stop.nil?
        len = seq_len(name)
        return "" if len.zero?

        start = 0
        stop = len - 1
      else
        validate_range!(name, start, stop)
      end
      fetch_result(native.fetch_qual(name, start, stop), "quality", name, start, stop)
    end

    def build_index(fai_path = nil, gzi_path = nil)
      self.class.build_index(@file_name, fai_path, gzi_path)
      self
    end

    private

    def native
      raise IOError, "closed Faidx" if closed?

      @native
    end

    def validate_range!(name, start, stop)
      raise ArgumentError, "Expect start to be >= 0" if start < 0
      raise ArgumentError, "Expect stop to be >= 0" if stop < 0
      raise ArgumentError, "Expect start to be <= stop" if start > stop

      len = seq_len(name)
      raise ArgumentError, "Expect stop to be < seq_len (#{len})" if stop >= len
    end

    def fetch_result(result, kind, name, start, stop)
      len, string = result
      case len
      when -2 then raise ArgumentError, "Sequence not found: #{name}"
      when -1 then raise HTS::Error, "Error fetching #{kind}: #{name}:#{start}-#{stop}"
      end
      raise HTS::Error, "Error fetching #{kind}: #{name}:#{start}-#{stop}" unless string

      string
    end

    def resolve_format(file_name, format)
      case format
      when :auto
        file_name.match?(/\.(fastq|fq)(\.gz|\.bgz)?\z/i) ? :fastq : :fasta
      when :fasta, :fastq
        format
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end
    end
  end
end
