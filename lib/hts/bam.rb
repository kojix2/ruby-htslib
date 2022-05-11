# frozen_string_literal: true

require_relative "../htslib"

require_relative "hts"
require_relative "bam/header"
require_relative "bam/cigar"
require_relative "bam/flag"
require_relative "bam/record"

module HTS
  # A class for working with SAM, BAM, CRAM files.
  class Bam
    include Enumerable

    attr_reader :file_name, :index_name, :mode, :header

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

    def initialize(file_name, mode = "r", index: nil, fai: nil, threads: nil,
                   create_index: false)
      if block_given?
        message = "HTS::Bam.new() dose not take block; Please use HTS::Bam.open() instead"
        raise message
      end

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      @file_name  = file_name
      @index_name = index
      @mode       = mode
      @hts_file   = LibHTS.hts_open(@file_name, mode)

      raise Errno::ENOENT, "Failed to open #{@file_name}" if @hts_file.null?

      if fai
        r = LibHTS.hts_set_fai_filename(@hts_file, fai)
        raise "Failed to load fasta index: #{fai}" if r < 0
      end

      if threads&.> 0
        r = LibHTS.hts_set_threads(@hts_file, threads)
        raise "Failed to set number of threads: #{threads}" if r < 0
      end

      return if @mode[0] == "w"

      @header = Bam::Header.new(@hts_file)
      create_index(index) if create_index
      @idx = load_index(index)
      @start_position = tell
      super # do nothing
    end

    def create_index(index_name = nil)
      check_closed

      warn "Create index for #{@file_name} to #{index_name}"
      if index
        LibHTS.sam_index_build2(@file_name, index_name, -1)
      else
        LibHTS.sam_index_build(@file_name, -1)
      end
    end

    def load_index(index_name = nil)
      check_closed

      if index_name
        LibHTS.sam_index_load2(@hts_file, @file_name, index_name)
      else
        LibHTS.sam_index_load3(@hts_file, @file_name, nil, 2) # should be 3 ? (copy remote file to local?)
      end
    end

    def index_loaded?
      check_closed

      !@idx.null?
    end

    # Close the current file.
    def close
      LibHTS.hts_idx_destroy(@idx) if @idx&.null?
      @idx = nil
      super
    end

    def write_header(header)
      check_closed

      @header = header.dup
      LibHTS.hts_set_fai_filename(@hts_file, @file_name)
      LibHTS.sam_hdr_write(@hts_file, header)
    end

    def write(aln)
      check_closed

      aln_dup = aln.dup
      LibHTS.sam_write1(@hts_file, header, aln_dup) > 0 || raise
    end

    # Iterate over each record.
    # Generate a new Record object each time.
    # Slower than each.
    def each_copy
      check_closed
      return to_enum(__method__) unless block_given?

      while LibHTS.sam_read1(@hts_file, header, bam1 = LibHTS.bam_init1) != -1
        record = Record.new(bam1, header)
        yield record
      end
      self
    end

    # Iterate over each record.
    # Record object is reused.
    # Faster than each_copy.
    def each
      check_closed
      # Each does not always start at the beginning of the file.
      # This is the common behavior of IO objects in Ruby.
      # This may change in the future.
      return to_enum(__method__) unless block_given?

      bam1 = LibHTS.bam_init1
      record = Record.new(bam1, header)
      yield record while LibHTS.sam_read1(@hts_file, header, bam1) != -1
      self
    end

    # query [WIP]
    def query(region)
      check_closed
      raise "Index file is required to call the query method." unless index_loaded?

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

    # @!macro [attach] generate
    #   @method $1
    #   Get $1 array
    #   @return [Array] the $1 array
    def self.define_getter(name)
      define_method(name) do
        check_closed
        position = tell
        ary = map(&name)
        seek(position)
        ary
      end
    end

    define_getter :qname
    define_getter :flag
    define_getter :chrom
    define_getter :pos
    define_getter :mapq
    define_getter :cigar
    define_getter :mate
    define_getter :mate_chrom
    define_getter :mate_pos
    define_getter :insert_size
    define_getter :seq
    define_getter :qual

    alias isize insert_size
    alias mpos mate_pos

    def aux(tag)
      warn "experimental"
      check_closed
      ary = map { |r| r.aux(tag) }
      rewind
      ary
    end
  end
end
