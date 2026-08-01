# frozen_string_literal: true

require_relative "../htslib"
require_relative "hts"
require_relative "native"
require_relative "bcf/errors"
require_relative "bcf/header"
require_relative "bcf/info"
require_relative "bcf/format"
require_relative "bcf/record"

module HTS
  class Bcf < Hts
    include Enumerable

    def self.filter_records(records, rid: nil, beg: nil, end_: nil, min_qual: nil, filter_id: nil)
      Array(records).select do |record|
        (rid.nil? || record.rid == Integer(rid)) &&
          (beg.nil? || record.endpos > Integer(beg)) && (end_.nil? || record.pos < Integer(end_)) &&
          (min_qual.nil? || (!record.qual.nan? && record.qual >= Float(min_qual))) &&
          (filter_id.nil? || record.filter_id?(filter_id))
      end
    end

    attr_reader :file_name, :index_name, :mode, :header, :nthreads, :unpack

    def self.open(*args, **keywords)
      file = new(*args, **keywords)
      return file unless block_given?

      begin
        yield file
      ensure
        file.close
      end
      file
    end

    def self.build_index(file_name, index_name = nil, min_shift = 14, threads = 0, verbose = true)
      warn(index_name ? "Create index for #{file_name} to #{index_name}" : "Create index for #{file_name}") if verbose
      case Native::BcfFileHandle.build_index(file_name, index_name, min_shift, threads)
      when 0 then nil
      when -1 then raise IndexError, "Indexing failed for #{file_name}"
      when -2 then raise IndexError, "Opening #{file_name} failed while building the index"
      when -3 then raise IndexError, "#{file_name} is not in an indexable format"
      when -4 then raise IndexError, "Failed to create or save the index for #{file_name}"
      else raise IndexError, "Unknown index build error for #{file_name}"
      end
    end

    def initialize(file_name, mode = "r", index: nil, threads: nil, build_index: false,
                   subset: nil, samples: nil, unpack: :all)
      raise "HTS::Bcf.new() does not take block; Please use HTS::Bcf.open() instead" if block_given?
      raise ArgumentError, "specify either samples: or subset:, not both" if samples && subset

      subset = samples unless samples.nil?
      @unpack = unpack.to_sym
      @max_unpack = resolve_max_unpack(@unpack)
      @file_name = file_name
      @index_name = index
      @mode = mode
      @nthreads = threads
      @native = Native::BcfFileHandle.open(@file_name, mode)
      set_threads(threads) if threads
      raise SubsetError, "Sample subsetting is only available when reading BCF/VCF files" if subset && mode.start_with?("w")
      return if mode.start_with?("w")

      @read_header = Header.new(@native.read_header)
      @header = subset ? @read_header.subset(subset) : @read_header
      build_index(index) if build_index
      load_index(index)
      @start_position = tell
    rescue Errno::ENOENT
      raise OpenError, "Failed to open #{@file_name}"
    end

    def build_index(index_name = nil, min_shift: 14, verbose: true)
      check_closed
      self.class.build_index(@file_name, index_name, min_shift, @nthreads || 0, verbose)
      self
    end

    def load_index(index_name = nil)
      check_closed
      @native.load_index(index_name)
    end

    def index_loaded?
      check_closed
      @native.index_loaded?
    end

    def close = @native&.close
    def closed? = @native.nil? || @native.closed?
    def file_format = @native.file_format
    def file_format_version = @native.file_format_version
    def seek(offset) = @native.seek(offset)
    def tell = @native.tell

    def rewind
      raise "Cannot rewind: no start position" unless @start_position
      result = seek(@start_position)
      raise "Failed to rewind: #{result}" if result.negative?
      tell
    end

    def set_threads(count = nil)
      if count.nil?
        require "etc"
        count = [Etc.nprocessors - 1, 1].max
      end
      raise TypeError unless count.is_a?(Integer)
      raise ArgumentError, "Number of threads must be positive" if count < 1
      raise "Failed to set number of threads: #{count}" if @native.set_threads(count).negative?
      @nthreads = count
      self
    end

    def write_header(header)
      check_closed
      @header = header.dup
      result = @native.write_header(header.__send__(:native_handle))
      raise HeaderError, "Failed to write BCF header" if result.negative?
      result
    end
    def header=(header)
      write_header(header)
    end

    def write(record)
      check_closed
      result = @native.write(header.__send__(:native_handle), record.__send__(:native_handle))
      raise "Failed to write record" if result.negative?
      result
    end
    alias << write

    def nsamples = (check_closed; header.nsamples)
    def samples = (check_closed; header.samples)

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
      raise NotImplementedError unless key
      position = tell
      map { |record| record.info(key) }.tap { seek(position) if position }
    end
    alias info_array info

    def format(key = nil)
      check_closed
      raise NotImplementedError unless key
      position = tell
      map { |record| record.format(key) }.tap { seek(position) if position }
    end
    alias format_array format

    def collect_records = each(copy: true).to_a

    define_iterator :chrom
    define_iterator :pos
    define_iterator :endpos
    define_iterator :id
    define_iterator :ref
    define_iterator :alt
    define_iterator :qual
    define_iterator :filter

    def each_info(key)
      return to_enum(__method__, key) unless block_given?
      each { |record| yield record.info(key) }
      self
    end

    def each_format(key)
      return to_enum(__method__, key) unless block_given?
      each { |record| yield record.format(key) }
      self
    end

    def each(copy: false, &block) = copy ? each_record_copy(&block) : each_record_reuse(&block)

    def query(region, beg = nil, end_ = nil, copy: false, &block)
      check_closed
      raise MissingIndexError, "Index file is required to call the query method for #{@file_name}" unless index_loaded?

      case region
      when Array
        raise ArgumentError, "beg and end must not be specified when region is an Array" unless beg.nil? && end_.nil?
        return to_enum(__method__, region, copy:) unless block
        region.each { |item| query(item, copy:, &block) }
        self
      else
        if beg && end_
          iterate_query(@native.query_interval(read_header_native, header.name2id(region), beg, end_), copy, region, &block)
        elsif beg.nil? && end_.nil?
          iterate_query(@native.query_region(read_header_native, region), copy, region, &block)
        else
          raise ArgumentError, "beg and end must be specified together"
        end
      end
    end

    private

    def native_handle = @native
    def read_header_native = (@read_header || @header).__send__(:native_handle)

    def each_record_reuse
      return to_enum(__method__) unless block_given?
      record = Record.new(header)
      prepare_record(record)
      loop do
        result = @native.read(read_header_native, record.__send__(:native_handle))
        break if result == -1
        raise QueryError, "Failed to read variant record from #{@file_name}" if result < -1
        apply_subset!(record)
        yield record
      end
      self
    end

    def each_record_copy
      return to_enum(__method__) unless block_given?
      each_record_reuse { |record| yield record.dup }
      self
    end

    def iterate_query(iterator, copy, region)
      return to_enum(__method__, iterator, copy, region) unless block_given?
      raise QueryError, "Failed to query region #{region.inspect} in #{@file_name}" unless iterator
      record = Record.new(header)
      prepare_record(record)
      begin
        loop do
          result = iterator.next(record.__send__(:native_handle))
          break if result == -1
          raise QueryError, "Failed to parse/query record in #{@file_name}" if result < -1
          apply_subset!(record)
          yield(copy ? record.dup : record)
        end
      ensure
        iterator.close
      end
      self
    end

    def apply_subset!(record)
      return unless header&.subset?
      map = header.__send__(:subset_imap)
      result = record.__send__(:native_handle).subset(header.__send__(:native_handle), map)
      raise SubsetError, "Failed to subset samples #{header.subset_samples.inspect} while reading #{@file_name}" if result.negative?
    end

    def resolve_max_unpack(level)
      case level
      when :all, :format then 15
      when :site_only, :info then 4
      when :filter then 2
      when :string, :alleles then 1
      else raise ArgumentError, "unknown unpack level: #{level.inspect}"
      end
    end

    def prepare_record(record)
      record.__send__(:native_handle).max_unpack = @max_unpack
    end
  end
end
