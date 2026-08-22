# frozen_string_literal: true

require_relative "../htslib"

require_relative "hts"
require_relative "native"

module HTS
  class Tabix < Hts
    include Enumerable

    class OpenError < HTS::Error; end
    class MissingIndexError < HTS::Error; end

    attr_reader :file_name, :index_name, :mode, :nthreads

    def self.open(*args, **kw)
      file = new(*args, **kw) # do not yield
      return file unless block_given?

      begin
        result = yield file
      ensure
        file.close
      end
      result
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
      @index_load_attempted = false
      @native = Native::TabixHandle.open(@file_name)

      set_threads(threads) if threads

      if build_index
        build_index(index)
        load_index(index)
      elsif index
        load_index(index)
      end
    end

    def build_index(index_name = nil, min_shift: 0)
      check_closed

      if index_name
        warn "Create index for #{@file_name} to #{index_name}"
        case Native::TabixHandle.build(@file_name, index_name, min_shift)
        when 0 # successful
        when -1 then raise "general failure"
        when -2 then raise "compression not BGZF"
        else raise "unknown error"
        end
      else
        warn "Create index for #{@file_name}"
        case Native::TabixHandle.build(@file_name, nil, min_shift)
        when 0 # successful
        when -1 then raise "general failure"
        when -2 then raise "compression not BGZF"
        else raise "unknown error"
        end
      end
      @index_name = index_name
      @index_load_attempted = false
      self # for method chaining
    end

    def load_index(index_name = nil)
      return self if try_load_index(index_name)

      raise MissingIndexError, "Failed to load index #{index_name || "for #{@file_name}"}"
    end

    def try_load_index(index_name = nil)
      check_closed
      @index_name = index_name
      @index_load_attempted = true
      @native.load_index(index_name)
    end

    def index_loaded?
      check_closed
      @native.index_loaded?
    end

    def name2id(name)
      check_closed
      raise "Index file is required to call the name2id method." unless ensure_index_loaded

      @native.name2id(name)
    end

    def seqnames
      check_closed
      raise "Index file is required to call the seqnames method." unless ensure_index_loaded

      @native.seqnames
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
      raise "Index file is required to call the query method." unless ensure_index_loaded

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

      @native.close
    end

    def closed?
      @native.nil? || @native.closed?
    end

    def file_format = @native.file_format
    def file_format_version = @native.file_format_version

    def set_threads(n = nil)
      if n.nil?
        require "etc"
        n = [Etc.nprocessors - 1, 1].max
      end
      raise TypeError unless n.is_a?(Integer)
      raise ArgumentError, "Number of threads must be positive" if n < 1
      raise "Failed to set number of threads: #{n}" if @native.set_threads(n).negative?

      @nthreads = n
      self
    end

    private

    def ensure_index_loaded
      return true if index_loaded?
      return false if @index_load_attempted

      load_index(@index_name)
    end

    def queryi(id, start, end_, mode = :fields, columns = nil, &block)
      return to_enum(__method__, id, start, end_, mode, columns) unless block_given?

      @native.query_interval(id, start, end_) { |line| yield_line(line, mode, columns, &block) }
      self
    end

    def querys(region, mode = :fields, columns = nil, &block)
      return to_enum(__method__, region, mode, columns) unless block_given?

      @native.query_region(region) { |line| yield_line(line, mode, columns, &block) }
      self
    end

    def yield_line(line, mode, columns)
      case mode
      when :line
        yield line
      when :selected
        yield selected_fields(line, columns)
      else
        yield line.split("\t")
      end
    end

    def selected_fields(line, columns)
      HTS::Native.selected_fields(line, columns)
    end

    def check_closed
      raise IOError, "closed Tabix" if closed?
    end
  end
end
