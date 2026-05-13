# frozen_string_literal: true

require_relative "../htslib"

require_relative "hts"

module HTS
  class Tabix < Hts
    include Enumerable

    attr_reader :file_name, :index_name, :mode, :nthreads

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

    def initialize(file_name, index: nil, threads: nil, build_index: false)
      if block_given?
        message = "HTS::Tabix.new() does not take block; Please use HTS::Tabix.open() instead"
        raise message
      end

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      @file_name  = file_name
      @index_name = index
      @mode       = "r"
      @nthreads   = threads
      @hts_file   = LibHTS.hts_open(@file_name, @mode)

      raise Errno::ENOENT, "Failed to open #{@file_name}" if @hts_file.null?

      set_threads(threads) if threads

      # build_index(index) if build_index
      @idx = load_index(index)
    end

    def build_index(index_name = nil, min_shift: 0)
      check_closed

      if index_name
        warn "Create index for #{@file_name} to #{index_name}"
        case LibHTS.tbx_index_build2(@file_name, index_name, min_shift, LibHTS.tbx_conf_vcf)
        when 0 # successful
        when -1 then raise "general failure"
        when -2 then raise "compression not BGZF"
        else raise "unknown error"
        end
      else
        warn "Create index for #{@file_name}"
        case LibHTS.tbx_index_build(@file_name, min_shift, LibHTS.tbx_conf_vcf)
        when 0 # successful
        when -1 then raise "general failure"
        when -2 then raise "compression not BGZF"
        else raise "unknown error"
        end
      end
      self # for method chaining
    end

    def load_index(index_name = nil)
      check_closed
      if index_name
        LibHTS.tbx_index_load2(@file_name, index_name)
      else
        LibHTS.tbx_index_load3(@file_name, nil, 2)
      end
    end

    def index_loaded?
      check_closed
      !@idx.null?
    end

    def name2id(name)
      check_closed
      LibHTS.tbx_name2id(@idx, name)
    end

    def seqnames
      check_closed
      nseq = FFI::MemoryPointer.new(:int)
      pts = LibHTS.tbx_seqnames(@idx, nseq)
      begin
        pts.read_array_of_pointer(nseq.read_int).map(&:read_string)
      ensure
        LibHTS.hts_free(pts) unless pts.null?
      end
    end

    def query(region, start = nil, end_ = nil, &block)
      check_closed
      raise "Index file is required to call the query method." unless index_loaded?

      if start && end_
        queryi(name2id(region), start, end_, &block)
      else
        querys(region, &block)
      end
    end

    def close
      return if closed?

      @idx.close if @idx && !@idx.null?
      @idx = nil
      super
    end

    def closed?
      @hts_file.nil? || @hts_file.null?
    end

    private

    def queryi(id, start, end_, &block)
      return to_enum(__method__, id, start, end_) unless block_given?

      qiter = LibHTS.tbx_itr_queryi(@idx, id, start, end_)
      raise "Failed to query region: #{id}:#{start}-#{end_}" if qiter.null?

      query_yield(qiter, &block)
      self
    end

    def querys(region, &block)
      return to_enum(__method__, region) unless block_given?

      qiter = LibHTS.tbx_itr_querys(@idx, region)
      raise "Failed to query region: #{region}" if qiter.null?

      query_yield(qiter, &block)
      self
    end

    def query_yield(qiter)
      r = LibHTS::KString.new
      begin
        yield r.read_string_copy.split("\t") while LibHTS.tbx_itr_next(@hts_file, @idx, qiter, r) > 0
      ensure
        r.free_buffer
        LibHTS.hts_itr_destroy(qiter)
      end
    end

    def check_closed
      raise IOError, "closed Tabix" if closed?
    end
  end
end
