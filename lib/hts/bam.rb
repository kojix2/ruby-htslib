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

    def self.open(*args)
      file = new(*args)
      return file unless block_given?

      begin
        yield file
      ensure
        file.close
      end
      file
    end

    def initialize(file_path, mode = "r", fai: nil, threads: nil, create_index: nil)
      raise "HTS::Bam.new() dose not take block; Please use HTS::Bam.open() instead" if block_given?

      file_path = File.expand_path(file_path)

      unless File.exist?(file_path)
        message = "No such SAM/BAM file - #{file_path}"
        raise message
      end

      @file_path = file_path
      @mode      = mode
      @hts_file  = LibHTS.hts_open(file_path, mode)

      if fai
        r = LibHTS.hts_set_fai_filename(@hts_file, fai)
        raise "Failed to load fasta index: #{fai}" if r < 0
      end

      if threads
        r = LibHTS.hts_set_threads(@hts_file, threads)
        raise "Failed to set number of threads: #{threads}" if r < 0
      end

      return if mode[0] == "w"

      @header = Bam::Header.new(@hts_file)

      # load index
      idx = LibHTS.sam_index_load(@hts_file, file_path)

      # create index
      if create_index || (idx.null? && create_index.nil?)
        warn "Create index for #{file_path}"
        LibHTS.sam_index_build(file_path, -1)
        @idx = LibHTS.sam_index_load(@hts_file, file_path)
      else
        @idx = idx
      end
    end

    def struct
      @hts_file
    end

    def to_ptr
      @hts_file.to_ptr
    end

    def write(alns)
      alns.each do
        LibHTS.sam_write1(@hts_file, header, alns.b) > 0 || raise
      end
    end

    def write_header(header)
      LibHTS.hts_set_fai_filename(header, @file_path)
      LibHTS.sam_hdr_write(@hts_file, header)
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

    # Flush the current file.
    def flush
      # LibHTS.bgzf_flush(@@hts_file.fp.bgzf)
    end

    def each
      # Each does not always start at the beginning of the file.
      # This is the common behavior of IO objects in Ruby.
      # This may change in the future.
      return to_enum(__method__) unless block_given?

      while LibHTS.sam_read1(@hts_file, header, bam1 = LibHTS.bam_init1) > 0
        record = Record.new(bam1, header)
        yield record
      end
      self
    end

    # query [WIP]
    def query(region)
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
