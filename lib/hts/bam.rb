# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative "bam/header"
require_relative "bam/cigar"
require_relative "bam/flag"
require_relative "bam/record"

module HTS
  class Bam
    include Enumerable

    attr_reader :file_path, :mode, :header

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

    def initialize(filename, mode = "r", fai: nil, threads: nil, index: nil)
      raise "HTS::Bam.new() dose not take block; Please use HTS::Bam.open() instead" if block_given?

      @file_path = filename == "-" ? "-" : File.expand_path(filename)

      if mode[0] == "r" && !File.exist?(file_path)
        message = "No such SAM/BAM file - #{file_path}"
        raise message
      end

      @mode      = mode
      @hts_file  = LibHTS.hts_open(file_path, mode)

      if fai
        fai_path = File.expand_path(fai)
        r = LibHTS.hts_set_fai_filename(@hts_file, fai_path)
        raise "Failed to load fasta index: #{fai}" if r < 0
      end

      if threads&.> 0
        r = LibHTS.hts_set_threads(@hts_file, threads)
        raise "Failed to set number of threads: #{threads}" if r < 0
      end

      return if mode[0] == "w"

      @header = Bam::Header.new(@hts_file)

      create_index if index

      # load index
      @idx = LibHTS.sam_index_load(@hts_file, file_path)
    end

    def create_index
      warn "Create index for #{file_path}"
      LibHTS.sam_index_build(file_path, -1)
      idx = LibHTS.sam_index_load(@hts_file, file_path)
      raise "Failed to load index: #{file_path}" if idx.null?
    end

    def struct
      @hts_file
    end

    def to_ptr
      @hts_file.to_ptr
    end

    # Close the current file.
    def close
      LibHTS.hts_idx_destroy(@idx) if @idx
      @idx = nil
      LibHTS.hts_close(@hts_file)
      @hts_file = nil
    end

    def closed?
      @hts_file.nil?
    end

    def write_header(header)
      @header = header.dup
      LibHTS.hts_set_fai_filename(@hts_file, @file_path)
      LibHTS.sam_hdr_write(@hts_file, header)
    end

    def write(aln)
      aln_dup = aln.dup
      LibHTS.sam_write1(@hts_file, header, aln_dup) > 0 || raise
    end

    # Flush the current file.
    def flush
      # LibHTS.bgzf_flush(@@hts_file.fp.bgzf)
    end

    # Iterate over each record.
    # Record object is reused.
    # Faster than each_copy.
    def each
      # Each does not always start at the beginning of the file.
      # This is the common behavior of IO objects in Ruby.
      # This may change in the future.
      return to_enum(__method__) unless block_given?

      bam1 = LibHTS.bam_init1
      record = Record.new(bam1, header)
      yield record while LibHTS.sam_read1(@hts_file, header, bam1) > 0
    end

    # Iterate over each record.
    # Generate a new Record object each time.
    # Slower than each.
    def each_copy
      return to_enum(__method__) unless block_given?

      while LibHTS.sam_read1(@hts_file, header, bam1 = LibHTS.bam_init1) > 0
        record = Record.new(bam1, header)
        yield record
      end
    end

    # query [WIP]
    def query(region)
      # FIXME: when @idx is nil
      qiter = LibHTS.sam_itr_querys(@idx, header, region)
      begin
        bam1 = LibHTS.bam_init1
        slen = LibHTS.sam_itr_next(@hts_file, qiter, bam1)
        while slen > 0
          yield Record.new(bam1, header)
          bam1 = LibHTS.bam_init1
          slen = LibHTS.sam_itr_next(@hts_file, qiter, bam1)
        end
      ensure
        LibHTS.hts_itr_destroy(qiter)
      end
    end
  end
end
