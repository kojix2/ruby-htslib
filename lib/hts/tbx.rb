# frozen_string_literal: true

require_relative "../htslib"

require_relative "hts"

module HTS
  class Tbx < Hts
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

    def initialize(file_name, mode = "r", index: nil, threads: nil, build_index: false)
      if block_given?
        message = "HTS::Tbx.new() dose not take block; Please use HTS::Tbx.open() instead"
        raise message
      end

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      @file_name  = file_name
      @index_name = index
      @mode       = mode
      @nthreads   = threads
      @hts_file = LibHTS.hts_open(@file_name, @mode)

      raise Errno::ENOENT, "Failed to open #{@file_name}" if @hts_file.null?

      set_threads(threads) if threads

      # return if @mode[0] == "w"
      raise "Not implemented" if @mode[0] == "w"

      # build_index(index) if build_index
      @idx = load_index(index)
    end

    def build_index
      raise "Not implemented yet"
    end

    def load_index(index_name = nil)
      if index_name
        LibHTS.tbx_index_load2(@file_name, index_name)
      else
        LibHTS.tbx_index_load3(@file_name, nil, 2)
      end
    end

    def index_loaded?
      !@idx.null?
    end

    def tid(name)
      LibHTS.tbx_name2id(@idx, name)
    end

    def seqnames
      nseq = FFI::MemoryPointer.new(:int)
      LibHTS.tbx_seqnames(@idx, nseq).then do |pts|
        pts.read_array_of_pointer(nseq.read_int).map(&:read_string)
      end
    end

    def query(region)
      check_closed
      raise "Index file is required to call the query method." unless index_loaded?
      return to_enum(__method__, region) unless block_given?

      qiter = LibHTS.tbx_itr_querys(@idx, region)

      raise "Failed to query region: #{region}" if qiter.null?

      r = LibHTS::KString.new
      begin
        yield r[:s] while LibHTS.tbx_itr_next(@hts_file, @idx, qiter, r) > 0
      ensure
        LibHTS.hts_itr_destroy(qiter)
      end
      self
    end
  end
end
