# frozen_string_literal: true

require_relative "../htslib"

require_relative "hts"
require_relative "bcf/header"
require_relative "bcf/info"
require_relative "bcf/format"
require_relative "bcf/record"

module HTS
  # A class for working with VCF, BCF files.
  class Bcf < Hts
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

    def initialize(file_name, mode = "r", index: nil, threads: nil,
                   build_index: false)
      if block_given?
        message = "HTS::Bcf.new() dose not take block; Please use HTS::Bcf.open() instead"
        raise message
      end

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      @file_name  = file_name
      @index_name = index
      @mode       = mode
      @nthreads   = threads
      @hts_file   = LibHTS.hts_open(@file_name, mode)

      raise Errno::ENOENT, "Failed to open #{@file_name}" if @hts_file.null?

      set_threads(threads) if threads

      return if @mode[0] == "w"

      @header = Bcf::Header.new(@hts_file)
      build_index(index) if build_index
      @idx = load_index(index)
      @start_position = tell
    end

    def build_index(index_name = nil, min_shift: 14, threads: 2)
      check_closed

      if index_name
        warn "Create index for #{@file_name} to #{index_name}"
      else
        warn "Create index for #{@file_name}"
      end
      case LibHTS.bcf_index_build3(@file_name, index_name, min_shift, (@nthreads || threads))
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
        LibHTS.bcf_index_load2(@file_name, index_name)
      else
        LibHTS.bcf_index_load3(@file_name, nil, 2)
      end
    end

    def index_loaded?
      check_closed

      !@idx.null?
    end

    def close
      LibHTS.hts_idx_destroy(@idx) unless @idx&.null?
      @idx = nil
      super
    end

    def write_header(header)
      check_closed

      @header = header.clone
      LibHTS.bcf_hdr_write(@hts_file, header)
    end

    def header=(header)
      write_header(header)
    end

    def write(record)
      check_closed

      # record = record.dup
      r = LibHTS.bcf_write(@hts_file, header, record)
      raise "Failed to write record" if r < 0
    end

    def <<(var)
      write(var)
    end

    def nsamples
      check_closed

      header.nsamples
    end

    def samples
      check_closed

      header.samples
    end

    # @!macro [attach] define_getter
    #   @method $1
    #   Get $1 array
    #   @return [Array] the $1 array
    define_getter :chrom
    define_getter :pos
    define_getter :endpos
    define_getter :id
    define_getter :ref
    define_getter :alt
    define_getter :qual
    define_getter :filter

    def info(key = nil)
      check_closed
      position = tell
      raise NotImplementedError unless key

      ary = map { |r| r.info(key) }

      # ary = each_copy.map { |r| r.info }
      # ary = map { |r| r.info.clone }

      seek(position)
      ary
    end

    def format(key = nil)
      check_closed
      position = tell
      raise NotImplementedError unless key

      ary = map { |r| r.format(key) }

      # ary = each_copy.map { |r| r.format }
      # ary = map { |r| r.format.clone }

      seek(position)
      ary
    end

    # @!macro [attach] define_iterator
    #   @method each_$1
    #   Get $1 iterator
    define_iterator :chrom
    define_iterator :pos
    define_iterator :endpos
    define_iterator :id
    define_iterator :ref
    define_iterator :alt
    define_iterator :qual
    define_iterator :filter

    def each_info(key)
      check_closed
      return to_enum(__method__, key) unless block_given?

      each do |r|
        yield r.info(key)
      end
    end

    def each_format(key)
      check_closed
      return to_enum(__method__, key) unless block_given?

      each do |r|
        yield r.format(key)
      end
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

      raise "query is only available for BCF files" unless file_format == "bcf"
      raise "Index file is required to call the query method." unless index_loaded?

      if beg && end_
        tid = header.name2id(region)
        queryi(tid, beg, end_, copy:, &block)
      elsif beg.nil? && end_.nil?
        querys(region, copy:, &block)
      else
        raise ArgumentError, "beg and end must be specified together"
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

    def queryi_reuse(tid, beg, end_, &block)
      return to_enum(__method__, tid, beg, end_) unless block_given?

      qiter = LibHTS.bcf_itr_queryi(@idx, tid, beg, end_)
      raise "Failed to query region #{tid} #{beg} #{end_}" if qiter.null?

      query_reuse_yield(qiter, &block)
      self
    end

    def querys_reuse(region, &block)
      return to_enum(__method__, region) unless block_given?

      qiter = LibHTS.bcf_itr_querys(@idx, header, region)
      raise "Failed to query region #{region}" if qiter.null?

      query_reuse_yield(qiter, &block)
      self
    end

    def query_reuse_yield(qiter)
      bcf1 = LibHTS.bcf_init
      record = Record.new(header, bcf1)
      begin
        loop do
          slen = LibHTS.hts_itr_next(@hts_file[:fp][:bgzf], qiter, bcf1, ::FFI::Pointer::NULL)
          break if slen == -1
          raise if slen < -1

          yield record
        end
      ensure
        LibHTS.bcf_itr_destroy(qiter)
      end
    end

    def queryi_copy(tid, beg, end_, &block)
      return to_enum(__method__, tid, beg, end_) unless block_given?

      qiter = LibHTS.bcf_itr_queryi(@idx, tid, beg, end_)
      raise "Failed to query region #{tid} #{beg} #{end_}" if qiter.null?

      query_copy_yield(qiter, &block)
      self
    end

    def querys_copy(region, &block)
      return to_enum(__method__, region) unless block_given?

      qiter = LibHTS.bcf_itr_querys(@idx, header, region)
      raise "Failed to query region #{region}" if qiter.null?

      query_copy_yield(qiter, &block)
      self
    end

    def query_copy_yield(qiter)
      loop do
        bcf1 = LibHTS.bcf_init
        slen = LibHTS.hts_itr_next(@hts_file[:fp][:bgzf], qiter, bcf1, ::FFI::Pointer::NULL)
        break if slen == -1
        raise if slen < -1

        yield Record.new(header, bcf1)
      end
    ensure
      LibHTS.bcf_itr_destroy(qiter)
    end

    def each_record_reuse
      check_closed

      return to_enum(__method__) unless block_given?

      bcf1 = LibHTS.bcf_init
      record = Record.new(header, bcf1)
      yield record while LibHTS.bcf_read(@hts_file, header, bcf1) != -1
      self
    end

    def each_record_copy
      check_closed

      return to_enum(__method__) unless block_given?

      while LibHTS.bcf_read(@hts_file, header, bcf1 = LibHTS.bcf_init) != -1
        record = Record.new(header, bcf1)
        yield record
      end
      self
    end
  end
end
