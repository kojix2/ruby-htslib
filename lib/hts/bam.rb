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

    attr_reader :file_name, :index_name, :mode, :header, :nthreads

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
                   build_index: false)
      if block_given?
        message = "HTS::Bam.new() dose not take block; Please use HTS::Bam.open() instead"
        raise message
      end

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      @file_name  = file_name
      @index_name = index
      @mode       = mode
      @nthreads   = threads
      @hts_file   = LibHTS.hts_open(@file_name, mode)

      raise Errno::ENOENT, "Failed to open #{@file_name}" if @hts_file.null?

      if fai
        r = LibHTS.hts_set_fai_filename(@hts_file, fai)
        raise "Failed to load fasta index: #{fai}" if r < 0
      end

      set_threads(threads) if threads

      return if @mode[0] == "w"

      @header = Bam::Header.new(@hts_file)
      build_index(index) if build_index
      @idx = load_index(index)
      @start_position = tell
    end

    def build_index(index_name = nil, min_shift: 0, threads: 2)
      check_closed

      if index_name
        warn "Create index for #{@file_name} to #{index_name}"
      else
        warn "Create index for #{@file_name}"
      end
      case LibHTS.sam_index_build3(@file_name, index_name, min_shift, (@nthreads || threads))
      when 0 # successful
      when -1 then raise "indexing failed"
      when -2 then raise "opening #{@file_name} failed"
      when -3 then raise "format not indexable"
      when -4 then raise "failed to create and/or save the index"
      else raise "unknown error"
      end
      self # for method chaining
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

    def close
      LibHTS.hts_idx_destroy(@idx) if @idx&.null?
      @idx = nil
      super
    end

    def write_header(header)
      check_closed

      @header = header.dup
      LibHTS.sam_hdr_write(@hts_file, header)
    end

    def header=(header)
      write_header(header)
    end

    def write(record)
      check_closed

      r = LibHTS.sam_write1(@hts_file, header, record)
      raise "Failed to write record" if r < 0
    end

    def <<(record)
      write(record)
    end

    # @!macro [attach] define_getter
    #   @method $1
    #   Get $1 array
    #   @return [Array] the $1 array
    define_getter :qname
    define_getter :flag
    define_getter :chrom
    define_getter :pos
    define_getter :mapq
    define_getter :cigar
    define_getter :mate_chrom
    define_getter :mate_pos
    define_getter :insert_size
    define_getter :seq
    define_getter :qual

    alias isize insert_size
    alias mpos mate_pos

    # FXIME: experimental
    def aux(tag)
      check_closed

      position = tell
      ary = map { |r| r.aux(tag) }
      seek(position)
      ary
    end

    # @!macro [attach] define_iterator
    #   @method each_$1
    #   Get $1 iterator
    define_iterator :qname
    define_iterator :flag
    define_iterator :chrom
    define_iterator :pos
    define_iterator :mapq
    define_iterator :cigar
    define_iterator :mate_chrom
    define_iterator :mate_pos
    define_iterator :insert_size
    define_iterator :seq
    define_iterator :qual

    alias each_isize each_insert_size
    alias each_mpos each_mate_pos

    # FIXME: experimental
    def each_aux(tag)
      check_closed
      return to_enum(__method__, tag) unless block_given?

      each do |record|
        yield record.aux(tag)
      end

      self
    end

    def each(copy: false, &block)
      if copy
        each_record_copy(&block)
      else
        each_record_reuse(&block)
      end
    end

    def query(region, beg = nil, end_ = nil, copy: false, &block)
      check_closed
      raise "Index file is required to call the query method." unless index_loaded?

      if beg && end_
        tid = header.get_tid(region)
        queryi(tid, beg, end_, copy:, &block)
      elsif beg.nil? && end_.nil?
        querys(region, copy:, &block)
      else
        raise ArgumentError, "beg and end_ must be specified together"
      end
    end

    private

    def queryi(tid, beg, end_, copy: false, &block)
      if copy
        queryi_copy(tid, beg, end_, &block)
      else
        queryi_reuse(tid, beg, end_, &block)
      end
    end

    def querys(region, copy: false, &block)
      if copy
        querys_copy(region, &block)
      else
        querys_reuse(region, &block)
      end
    end

    def each_record_reuse
      check_closed
      # Each does not always start at the beginning of the file.
      # This is the common behavior of IO objects in Ruby.
      return to_enum(__method__) unless block_given?

      bam1 = LibHTS.bam_init1
      record = Record.new(header, bam1)
      yield record while LibHTS.sam_read1(@hts_file, header, bam1) != -1
      self
    end

    def each_record_copy
      check_closed
      return to_enum(__method__) unless block_given?

      while LibHTS.sam_read1(@hts_file, header, bam1 = LibHTS.bam_init1) != -1
        record = Record.new(header, bam1)
        yield record
      end
      self
    end

    def queryi_reuse(tid, beg, end_, &block)
      return to_enum(__method__, region, beg, end_) unless block_given?

      qiter = LibHTS.sam_itr_queryi(@idx, tid, beg, end_)
      raise "Failed to query region: #{tid} #{beg} #{end_}" if qiter.null?

      query_reuse_yield(qiter, &block)
      self
    end

    def queryi_copy(tid, beg, end_, &block)
      return to_enum(__method__, tid, beg, end_) unless block_given?

      qiter = LibHTS.sam_itr_queryi(@idx, tid, beg, end_)
      raise "Failed to query region: #{tid} #{beg} #{end_}" if qiter.null?

      query_copy(qiter, &block)
      self
    end

    def querys_reuse(region, &block)
      return to_enum(__method__, region) unless block_given?

      qiter = LibHTS.sam_itr_querys(@idx, header, region)
      raise "Failed to query region: #{region}" if qiter.null?

      query_reuse_yield(qiter, &block)
      self
    end

    def querys_copy(region, &block)
      return to_enum(__method__, region) unless block_given?

      qiter = LibHTS.sam_itr_querys(@idx, header, region)
      raise "Failed to query region: #{region}" if qiter.null?

      query_copy(qiter, &block)
      self
    end

    def query_reuse_yield(qiter)
      bam1 = LibHTS.bam_init1
      record = Record.new(header, bam1)
      begin
        yield record while LibHTS.sam_itr_next(@hts_file, qiter, bam1) > 0
      ensure
        LibHTS.hts_itr_destroy(qiter)
      end
    end

    def query_copy(qiter)
      loop do
        bam1 = LibHTS.bam_init1
        slen = LibHTS.sam_itr_next(@hts_file, qiter, bam1)
        break if slen == -1
        raise if slen < -1

        yield Record.new(header, bam1)
      end
    ensure
      LibHTS.hts_itr_destroy(qiter)
    end
  end
end
