# frozen_string_literal: true

require_relative "../htslib"

module HTS
  module LibC
    extend FFI::Library
    ffi_lib FFI::Library::LIBC
    attach_function :free, [:pointer], :void
  end
end

module HTS
  class Faidx
    attr_reader :file_name, :format

    def self.open(file_name, format: :auto, auto_build: true)
      file = new(file_name, format:, auto_build:) # do not yield
      return file unless block_given?

      begin
        yield file
      ensure
        file.close
      end
      file
    end

    def self.build_index(file_name, fai_path = nil, gzi_path = nil)
      case LibHTS.fai_build3(file_name, fai_path, gzi_path)
      when 0
      else raise HTS::Error, "Failed to build faidx index for #{file_name}"
      end
    end

    def initialize(file_name, format: :auto, auto_build: true)
      raise ArgumentError, "HTS::Faidx.new() does not take block; Please use HTS::Faidx.open() instead" if block_given?

      @file_name = file_name.freeze
      @format = resolve_format(@file_name, format)
      @fai = load_handle(@file_name, @format, auto_build)

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

    def size
      check_closed
      LibHTS.faidx_nseq(@fai)
    end

    alias length size

    def names
      check_closed
      Array.new(length) { |i| LibHTS.faidx_iseq(@fai, i) }
    end

    def has_seq?(key)
      check_closed
      raise ArgumentError, "Expect chrom to be String or Symbol" unless key.is_a?(String) || key.is_a?(Symbol)

      key = key.to_s
      case LibHTS.faidx_has_seq(@fai, key)
      when 1 then true
      when 0 then false
      else raise HTS::Error, "Unexpected return value from faidx_has_seq"
      end
    end

    def seq_len(chrom)
      check_closed
      raise ArgumentError, "Expect chrom to be String or Symbol" unless chrom.is_a?(String) || chrom.is_a?(Symbol)

      chrom = chrom.to_s
      result = LibHTS.faidx_seq_len64(@fai, chrom)
      raise ArgumentError, "Sequence not found: #{chrom}" if result == -1

      result
    end

    def fetch_seq(name, start = nil, stop = nil)
      check_closed
      name = name.to_s

      if start.nil? && stop.nil?
        len = seq_len(name)
        return "" if len.zero?

        fetch_seq(name, 0, len - 1)
      else
        validate_range!(name, start, stop)
        rlen = FFI::MemoryPointer.new(:int64)
        result = LibHTS.faidx_fetch_seq64(@fai, name, start, stop, rlen)
        fetch_result(result, rlen.read_int64, "sequence", name, start, stop)
      end
    end

    def fetch_qual(name, start = nil, stop = nil)
      check_closed
      raise HTS::Error, "Quality is only available for FASTQ indexes" unless format == :fastq

      name = name.to_s

      if start.nil? && stop.nil?
        len = seq_len(name)
        return "" if len.zero?

        fetch_qual(name, 0, len - 1)
      else
        validate_range!(name, start, stop)
        rlen = FFI::MemoryPointer.new(:int64)
        result = LibHTS.faidx_fetch_qual64(@fai, name, start, stop, rlen)
        fetch_result(result, rlen.read_int64, "quality", name, start, stop)
      end
    end

    def build_index(fai_path = nil, gzi_path = nil)
      self.class.build_index(@file_name, fai_path, gzi_path)
      self
    end

    private

    def check_closed
      raise IOError, "closed Faidx" if closed?
    end

    def validate_range!(name, start, stop)
      raise ArgumentError, "Expect start to be >= 0" if start < 0
      raise ArgumentError, "Expect stop to be >= 0" if stop < 0
      raise ArgumentError, "Expect start to be <= stop" if start > stop

      len = seq_len(name)
      raise ArgumentError, "Expect stop to be < seq_len (#{len})" if stop >= len
    end

    def fetch_result(ptr, len, kind, name, start, stop)
      case len
      when -2 then raise ArgumentError, "Sequence not found: #{name}"
      when -1 then raise HTS::Error, "Error fetching #{kind}: #{name}:#{start}-#{stop}"
      end

      raise HTS::Error, "Error fetching #{kind}: #{name}:#{start}-#{stop}" if ptr.null?

      begin
        ptr.read_string_length(len)
      ensure
        HTS::LibC.free(ptr)
      end
    end

    def load_handle(file_name, format, auto_build)
      case [format, auto_build]
      when [:fasta, true]
        LibHTS.fai_load_format(file_name, :FAI_FASTA)
      when [:fastq, true]
        LibHTS.fai_load_format(file_name, :FAI_FASTQ)
      when [:fasta, false]
        LibHTS.fai_load3_format(file_name, nil, nil, 0, :FAI_FASTA)
      when [:fastq, false]
        LibHTS.fai_load3_format(file_name, nil, nil, 0, :FAI_FASTQ)
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end
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
