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
      query_with_mode(region, start, end_, :fields, nil, &block)
    end

    # Explicit name for the legacy split-fields API.
    def each_fields(region, start = nil, end_ = nil, &block)
      query_with_mode(region, start, end_, :fields, nil, &block)
    end

    # Iterate raw rows, allocating one String per row and no field Array.
    def each_line(region, start = nil, end_ = nil, &block)
      query_with_mode(region, start, end_, :line, nil, &block)
    end

    # Extract only requested zero-based columns without materializing unused
    # field strings. This Ruby implementation scans tab delimiters once.
    def each_selected_fields(region, *columns, &block)
      raise ArgumentError, "at least one column index is required" if columns.empty?

      normalized = columns.map do |column|
        index = Integer(column)
        raise ArgumentError, "column indices must be non-negative" if index.negative?

        index
      end
      query_with_mode(region, nil, nil, :selected, normalized, &block)
    end

    def query_with_mode(region, start, end_, mode, columns, &block)
      check_closed
      raise "Index file is required to call the query method." unless index_loaded?

      if start && end_
        queryi(name2id(region), start, end_, mode, columns, &block)
      elsif start.nil? && end_.nil?
        querys(region, mode, columns, &block)
      else
        raise ArgumentError, "start and end must be specified together"
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

    def queryi(id, start, end_, mode = :fields, columns = nil, &block)
      return to_enum(__method__, id, start, end_, mode, columns) unless block_given?

      qiter = LibHTS.tbx_itr_queryi(@idx, id, start, end_)
      raise "Failed to query region: #{id}:#{start}-#{end_}" if qiter.null?

      query_yield(qiter, mode, columns, &block)
      self
    end

    def querys(region, mode = :fields, columns = nil, &block)
      return to_enum(__method__, region, mode, columns) unless block_given?

      qiter = LibHTS.tbx_itr_querys(@idx, region)
      raise "Failed to query region: #{region}" if qiter.null?

      query_yield(qiter, mode, columns, &block)
      self
    end

    def query_yield(qiter, mode, columns)
      r = LibHTS::KString.new
      begin
        while (slen = LibHTS.tbx_itr_next(@hts_file, @idx, qiter, r)) >= 0
          line = r.read_string_copy
          case mode
          when :line
            yield line
          when :selected
            yield selected_fields(line, columns)
          else
            yield line.split("\t")
          end
        end
        raise if slen < -1
      ensure
        r.free_buffer
        LibHTS.hts_itr_destroy(qiter)
      end
    end

    def selected_fields(line, columns)
      requested = {}
      columns.each_with_index { |column, result_index| (requested[column] ||= []) << result_index }
      result = Array.new(columns.length)
      max_column = columns.max
      field_start = 0
      column = 0
      byte_index = 0

      while byte_index <= line.bytesize && column <= max_column
        if byte_index == line.bytesize || line.getbyte(byte_index) == 9
          if (result_indices = requested[column])
            value = line.byteslice(field_start, byte_index - field_start)
            result_indices.each { |result_index| result[result_index] = value }
          end
          column += 1
          field_start = byte_index + 1
        end
        byte_index += 1
      end
      result
    end

    def check_closed
      raise IOError, "closed Tabix" if closed?
    end
  end
end
