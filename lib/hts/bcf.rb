# frozen_string_literal: true

require_relative "../htslib"

require_relative "hts"
require_relative "native"
require_relative "bcf/errors"
require_relative "bcf/header"
require_relative "bcf/getter_buffer"
require_relative "bcf/info"
require_relative "bcf/format"
require_relative "bcf/record"

module HTS
  # A class for working with VCF, BCF files.
  class Bcf < Hts
    include Enumerable

    # Filter an owning batch of records in one native pass when available.
    def self.filter_records(records, rid: nil, beg: nil, end_: nil,
                            min_qual: nil, filter_id: nil)
      Native.bcf_filter_records(
        Array(records), rid.nil? ? nil : Integer(rid),
        beg.nil? ? nil : Integer(beg), end_.nil? ? nil : Integer(end_),
        min_qual.nil? ? nil : Float(min_qual),
        filter_id.nil? ? nil : Integer(filter_id)
      )
    end

    attr_reader :file_name, :index_name, :mode, :header, :nthreads, :unpack

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

    def self.build_index(file_name, index_name = nil, min_shift = 14, threads = 0, verbose = true)
      if verbose
        if index_name
          warn "Create index for #{file_name} to #{index_name}"
        else
          warn "Create index for #{file_name}"
        end
      end

      case LibHTS.bcf_index_build3(file_name, index_name, min_shift, threads)
      when 0 # successful
      when -1 then raise IndexError, "Indexing failed for #{file_name}"
      when -2 then raise IndexError, "Opening #{file_name} failed while building the index"
      when -3 then raise IndexError, "#{file_name} is not in an indexable format"
      when -4 then raise IndexError, "Failed to create or save the index for #{file_name}"
      else raise IndexError, "Unknown index build error for #{file_name}"
      end
    end

    def initialize(file_name, mode = "r", index: nil, threads: nil,
                   build_index: false, subset: nil, samples: nil, unpack: :all)
      if block_given?
        message = "HTS::Bcf.new() does not take block; Please use HTS::Bcf.open() instead"
        raise message
      end

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      raise ArgumentError, "specify either samples: or subset:, not both" if samples && subset

      subset = samples unless samples.nil?
      @unpack = unpack.to_sym
      @max_unpack = resolve_max_unpack(@unpack)
      @file_name  = file_name
      @index_name = index
      @mode       = mode
      @nthreads   = threads
      @hts_file   = LibHTS.hts_open(@file_name, mode)

      raise OpenError, "Failed to open #{@file_name}" if @hts_file.null?

      set_threads(threads) if threads

      raise SubsetError, "Sample subsetting is only available when reading BCF/VCF files" if subset && @mode[0] == "w"

      return if @mode[0] == "w"

      @read_header = Bcf::Header.new(@hts_file)
      @header = subset ? @read_header.subset(subset) : @read_header
      configure_sample_selection!(@header.subset_samples) if subset
      build_index(index) if build_index
      @idx = load_index(index)
      @start_position = tell
    end

    def build_index(index_name = nil, min_shift: 14, verbose: true)
      check_closed

      self.class.build_index(@file_name, index_name, min_shift, @nthreads || 0, verbose)
      self # for method chaining
    end

    def load_index(index_name = nil)
      check_closed

      if file_format == "vcf"
        @index_format = :tabix
        if index_name
          LibHTS.tbx_index_load2(@file_name, index_name)
        else
          LibHTS.tbx_index_load3(@file_name, nil, 2)
        end
      elsif index_name
        @index_format = :bcf
        LibHTS.bcf_index_load2(@file_name, index_name)
      else
        @index_format = :bcf
        LibHTS.bcf_index_load3(@file_name, nil, 2)
      end
    end

    def index_loaded?
      check_closed

      !@idx.null?
    end

    def close
      if @idx && !@idx.null?
        case @index_format
        when :bcf
          LibHTS.hts_idx_destroy(@idx)
        when :tabix
          @idx.close
        end
      end
      @idx = nil
      super
    end

    def write_header(header)
      check_closed

      @header = header.dup
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

    alias info_array info

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

    alias format_array format

    # Materialize independent records from the current stream position.
    # Unlike each.to_a, every element owns its bcf1_t storage.
    def collect_records
      each(copy: true).to_a
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

      raise MissingIndexError, "Index file is required to call the query method for #{@file_name}" unless index_loaded?

      case region
      when Array
        raise ArgumentError, "beg and end must not be specified when region is an Array" unless beg.nil? && end_.nil?

        query_regions(region, copy:, &block)
      else
        if beg && end_
          tid = header.name2id(region)
          queryi(tid, beg, end_, copy:, &block)
        elsif beg.nil? && end_.nil?
          querys(region, copy:, &block)
        else
          raise ArgumentError, "beg and end must be specified together"
        end
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

    def query_regions(regions, copy: false, &block)
      if copy
        query_regions_copy(regions, &block)
      else
        query_regions_reuse(regions, &block)
      end
    end

    def queryi_reuse(tid, beg, end_, &block)
      return to_enum(__method__, tid, beg, end_) unless block_given?

      return queryi_reuse_vcf(tid, beg, end_, &block) if tabix_index?

      qiter = LibHTS.bcf_itr_queryi(@idx, tid, beg, end_)
      raise QueryError, "Failed to query region #{tid}:#{beg}-#{end_} in #{@file_name}" if qiter.null?

      query_reuse_yield(qiter, &block)
      self
    end

    def querys_reuse(region, &block)
      return to_enum(__method__, region) unless block_given?

      return querys_reuse_vcf(region, &block) if tabix_index?

      qiter = LibHTS.bcf_itr_querys(@idx, read_header, region)
      raise QueryError, "Failed to query region #{region.inspect} in #{@file_name}" if qiter.null?

      query_reuse_yield(qiter, &block)
      self
    end

    def query_regions_reuse(regions, &block)
      return to_enum(__method__, regions) unless block_given?

      regions.each do |region|
        querys_reuse(region, &block)
      end
      self
    end

    def query_reuse_yield(qiter)
      bcf1 = LibHTS.bcf_init
      prepare_record(bcf1)
      record = Record.new(header, bcf1)
      begin
        loop do
          slen = LibHTS.bcf_itr_next(@hts_file, qiter, bcf1)
          break if slen == -1
          raise if slen < -1

          apply_subset!(record, indexed: true)
          yield record
        end
      ensure
        LibHTS.bcf_itr_destroy(qiter)
      end
    end

    def queryi_copy(tid, beg, end_, &block)
      return to_enum(__method__, tid, beg, end_) unless block_given?

      return queryi_copy_vcf(tid, beg, end_, &block) if tabix_index?

      qiter = LibHTS.bcf_itr_queryi(@idx, tid, beg, end_)
      raise QueryError, "Failed to query region #{tid}:#{beg}-#{end_} in #{@file_name}" if qiter.null?

      query_copy_yield(qiter, &block)
      self
    end

    def querys_copy(region, &block)
      return to_enum(__method__, region) unless block_given?

      return querys_copy_vcf(region, &block) if tabix_index?

      qiter = LibHTS.bcf_itr_querys(@idx, read_header, region)
      raise QueryError, "Failed to query region #{region.inspect} in #{@file_name}" if qiter.null?

      query_copy_yield(qiter, &block)
      self
    end

    def query_regions_copy(regions, &block)
      return to_enum(__method__, regions) unless block_given?

      regions.each do |region|
        querys_copy(region, &block)
      end
      self
    end

    def query_copy_yield(qiter)
      bcf1 = LibHTS.bcf_init
      prepare_record(bcf1)
      record = Record.new(header, bcf1)
      loop do
        slen = LibHTS.bcf_itr_next(@hts_file, qiter, bcf1)
        break if slen == -1
        raise if slen < -1

        apply_subset!(record, indexed: true)
        yield record.dup
      end
    ensure
      LibHTS.bcf_itr_destroy(qiter)
    end

    def tabix_index?
      @index_format == :tabix
    end

    def queryi_reuse_vcf(tid, beg, end_, &block)
      qiter = LibHTS.tbx_itr_queryi(@idx, tid, beg, end_)
      raise QueryError, "Failed to query region #{tid}:#{beg}-#{end_} in #{@file_name}" if qiter.null?

      query_reuse_yield_vcf(qiter, &block)
      self
    end

    def querys_reuse_vcf(region, &block)
      qiter = LibHTS.tbx_itr_querys(@idx, region)
      raise QueryError, "Failed to query region #{region.inspect} in #{@file_name}" if qiter.null?

      query_reuse_yield_vcf(qiter, &block)
      self
    end

    def query_reuse_yield_vcf(qiter)
      line = LibHTS::KString.new
      bcf1 = LibHTS.bcf_init
      prepare_record(bcf1)
      record = Record.new(header, bcf1)
      begin
        while (slen = LibHTS.tbx_itr_next(@hts_file, @idx, qiter, line)) >= 0
          raise QueryError, "Failed to parse VCF record in #{@file_name}" if LibHTS.vcf_parse(line, read_header,
                                                                                              bcf1) < 0

          apply_subset!(record)
          yield record
        end
        raise if slen < -1
      ensure
        line.free_buffer
        LibHTS.hts_itr_destroy(qiter)
      end
    end

    def queryi_copy_vcf(tid, beg, end_, &block)
      qiter = LibHTS.tbx_itr_queryi(@idx, tid, beg, end_)
      raise QueryError, "Failed to query region #{tid}:#{beg}-#{end_} in #{@file_name}" if qiter.null?

      query_copy_yield_vcf(qiter, &block)
      self
    end

    def querys_copy_vcf(region, &block)
      qiter = LibHTS.tbx_itr_querys(@idx, region)
      raise QueryError, "Failed to query region #{region.inspect} in #{@file_name}" if qiter.null?

      query_copy_yield_vcf(qiter, &block)
      self
    end

    def query_copy_yield_vcf(qiter)
      line = LibHTS::KString.new
      begin
        while (slen = LibHTS.tbx_itr_next(@hts_file, @idx, qiter, line)) >= 0
          bcf1 = LibHTS.bcf_init
          prepare_record(bcf1)
          raise QueryError, "Failed to parse VCF record in #{@file_name}" if LibHTS.vcf_parse(line, read_header,
                                                                                              bcf1) < 0

          record = Record.new(header, bcf1)
          apply_subset!(record)
          yield record
        end
        raise if slen < -1
      ensure
        line.free_buffer
        LibHTS.hts_itr_destroy(qiter)
      end
    end

    def each_record_reuse
      check_closed

      return to_enum(__method__) unless block_given?

      bcf1 = LibHTS.bcf_init
      prepare_record(bcf1)
      record = Record.new(header, bcf1)
      while LibHTS.bcf_read(@hts_file, read_header, bcf1) != -1
        apply_subset!(record)
        yield record
      end
      self
    end

    def each_record_copy
      check_closed

      return to_enum(__method__) unless block_given?

      bcf1 = LibHTS.bcf_init
      prepare_record(bcf1)
      record = Record.new(header, bcf1)
      while LibHTS.bcf_read(@hts_file, read_header, bcf1) != -1
        apply_subset!(record)
        yield record.dup
      end
      self
    end

    def read_header
      @read_header || header
    end

    def apply_subset!(record, indexed: false)
      return unless header.subset?

      # bcf_read() and vcf_parse() see the configured header and subset while
      # parsing. Indexed BCF iteration bypasses the header and needs the
      # dedicated post-read FORMAT subsetting helper.
      return if @native_sample_subset && !indexed

      rc = if @native_sample_subset
             LibHTS.bcf_subset_format(read_header.struct, record.struct)
           else
             LibHTS.bcf_subset(
               header.struct, record.struct, header.subset_sample_count,
               header.subset_imap_pointer || ::FFI::Pointer::NULL
             )
           end
      return if rc >= 0

      raise SubsetError, "Failed to subset samples #{header.subset_samples.inspect} while reading #{@file_name}"
    end

    def configure_sample_selection!(samples)
      sample_list = samples.empty? ? nil : samples.join(",")
      rc = LibHTS.bcf_hdr_set_samples(@read_header.struct, sample_list, 0)
      raise SubsetError, "Failed to configure sample selection #{samples.inspect}" unless rc.zero?

      @native_sample_subset = true
    end

    def resolve_max_unpack(level)
      case level
      when :all, :format then LibHTS::BCF_UN_ALL
      when :site_only, :info then LibHTS::BCF_UN_INFO
      when :filter then LibHTS::BCF_UN_FLT
      when :string, :alleles then LibHTS::BCF_UN_STR
      else
        raise ArgumentError, "unknown unpack level: #{level.inspect}"
      end
    end

    def prepare_record(record)
      record[:max_unpack] = @max_unpack
    end
  end
end
