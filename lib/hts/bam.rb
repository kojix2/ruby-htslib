# frozen_string_literal: true

require_relative "../htslib"

require_relative "hts"
require_relative "bam/header"
require_relative "bam/cigar"
require_relative "bam/flag"
require_relative "bam/record"
require_relative "bam/base_mod"
require_relative "bam/pileup"
require_relative "bam/mpileup"
# require_relative "bam/pileup_entry"

module HTS
  # A class for working with SAM, BAM, CRAM files.
  class Bam
    include Enumerable

    class ReadError < HTS::Error; end
    class WriteError < HTS::Error; end
    class OpenError < HTS::Error; end

    # Filter an owning batch of records in one native pass when available.
    def self.filter_records(records, required_flags: 0, excluded_flags: 0,
                            min_mapq: 0, tid: nil, beg: nil, end_: nil)
      required_flags = Integer(required_flags)
      excluded_flags = Integer(excluded_flags)
      min_mapq = Integer(min_mapq)
      Array(records).select do |record|
        flags = record.flag_value
        (flags & required_flags) == required_flags && (flags & excluded_flags).zero? &&
          record.mapq >= min_mapq && (tid.nil? || record.tid == Integer(tid)) &&
          (beg.nil? || record.endpos > Integer(beg)) && (end_.nil? || record.pos < Integer(end_))
      end
    end

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

    def self.build_index(file_name, index_name = nil, min_shift = 0, threads = 0, verbose = true)
      if verbose
        if index_name
          warn "Create index for #{file_name} to #{index_name}"
        else
          warn "Create index for #{file_name}"
        end
      end

      case Native::BamFileHandle.build_index(file_name, index_name, min_shift, threads)
      when 0 # successful
      when -1 then raise "indexing failed"
      when -2 then raise "opening #{file_name} failed"
      when -3 then raise "format not indexable"
      when -4 then raise "failed to create and/or save the index"
      else raise "unknown error"
      end
    end

    def initialize(file_name, mode = "r", index: nil, fai: nil, threads: nil,
                   build_index: false)
      if block_given?
        message = "HTS::Bam.new() does not take block; Please use HTS::Bam.open() instead"
        raise message
      end

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      @file_name  = file_name
      @index_name = index
      @mode       = mode
      @nthreads   = threads
      @index_load_attempted = false
      @native = Native::BamFileHandle.open(@file_name, mode)

      # Auto-detect and set reference for CRAM files
      if fai.nil? && @file_name.end_with?(".cram")
        # Try to find reference file in the same directory
        base_name = File.basename(@file_name, ".cram")
        dir_name = File.dirname(@file_name)
        potential_ref = File.join(dir_name, "#{base_name}.fa")

        # For remote URLs, assume reference exists; for local files, check existence
        fai = potential_ref if @file_name.start_with?("http") || File.exist?(potential_ref)
      end

      if fai
        r = @native.set_fai(fai)
        raise "Failed to load fasta index: #{fai}" if r < 0
      end

      set_threads(threads) if threads

      return if @mode[0] == "w"

      @header = Bam::Header.new(@native.read_header)
      if build_index
        build_index(index)
        load_index(index)
      elsif index
        load_index(index)
      end
      @start_position = tell
    end

    def build_index(index_name = nil, min_shift: 0, verbose: true)
      check_closed

      self.class.build_index(@file_name, index_name, min_shift, @nthreads || 0, verbose)
      @index_name = index_name
      @index_load_attempted = false
      self # for method chaining
    end

    def load_index(index_name = nil)
      check_closed

      @index_name = index_name
      @index_load_attempted = true
      @native.load_index(index_name)
    end

    def index_loaded?
      check_closed

      @native.index_loaded?
    end

    def close
      result = @native&.close
      raise WriteError, "Failed to close #{@file_name}: buffered output may be incomplete" if writing? && result&.negative?

      nil
    end

    def closed? = @native.nil? || @native.closed?
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

    def seek(offset) = @native.seek(offset)
    def tell = @native.tell

    def rewind
      raise "Cannot rewind: no start position" unless @start_position

      result = seek(@start_position)
      raise "Failed to rewind: #{result}" if result.negative?

      tell
    end

    private

    def writing? = @mode&.start_with?("w", "a")

    def native_handle = @native

    public

    def write_header(header)
      check_closed

      @header = header.dup
      @native.write_header(header.__send__(:native_handle))
    end

    def header=(header)
      write_header(header)
    end

    def write(record)
      check_closed

      r = @native.write(header.__send__(:native_handle), record.__send__(:native_handle))
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

    # FIXME: experimental
    def aux(tag)
      check_closed

      position = tell
      ary = map { |r| r.aux(tag) }
      seek(position) if position
      ary
    end
    alias aux_array aux

    # Materialize independent records from the current stream position.
    # Unlike each.to_a, every element owns its bam1_t storage.
    def collect_records
      each(copy: true).to_a
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

    # Iterate alignment records in this file.
    #
    # Performance and memory semantics:
    # - copy: false (default) reuses a single Record instance and its underlying bam1_t buffer.
    #   The yielded Record MUST NOT be stored beyond the block; its content will be overwritten
    #   by the next iteration. If you need to retain it, call `rec = rec.dup`.
    # - copy: true yields a fresh Record per iteration (deep-copied via bam_dup1). Slower, safe to keep.
    def each(copy: false, &block)
      if copy
        each_record_copy(&block)
      else
        each_record_reuse(&block)
      end
    end

    # Iterate records in a genomic region or multiple regions.
    # See {#each} for copy semantics. When copy: false, the yielded Record is reused and should not be stored.
    #
    # @param region [String, Array<String>] Region specification(s)
    #   - Single region: "chr1:100-200" or "chr1" with beg/end parameters
    #   - Multiple regions: ["chr1:100-200", "chr2:500-600", ...]
    # @param beg [Integer, nil] Start position (used with single string region)
    # @param end_ [Integer, nil] End position (used with single string region)
    # @param copy [Boolean] Whether to deep-copy records (see {#each})
    #
    # @example Single region query
    #   bam.query("chr1:100-200") { |r| puts r.qname }
    #   bam.query("chr1", 100, 200) { |r| puts r.qname }
    #
    # @example Multi-region query
    #   bam.query(["chr1:100-200", "chr2:500-600"]) { |r| puts r.qname }
    def query(region, beg = nil, end_ = nil, copy: false, &block)
      check_closed
      raise "Index file is required to call the query method." unless ensure_index_loaded

      case region
      when Array
        raise ArgumentError, "beg and end_ cannot be used with array of regions" if beg || end_

        query_regions(region, copy:, &block)
      when String
        if beg && end_
          tid = header.get_tid(region)
          queryi(tid, beg, end_, copy:, &block)
        elsif beg.nil? && end_.nil?
          querys(region, copy:, &block)
        else
          raise ArgumentError, "beg and end_ must be specified together"
        end
      else
        raise ArgumentError, "region must be String or Array"
      end
    end

    # Pileup iterator over this file. Optional region can be specified.
    # When a block is given, uses RAII-style and ensures the iterator is closed at block end.
    # Without a block, returns an Enumerator over a live Pileup instance; caller should close when done.
    #
    # @param region [String, nil] region string like "chr1:100-200"
    # @param beg [Integer, nil]
    # @param end_ [Integer, nil]
    # @param maxcnt [Integer, nil] cap on depth per position
    def pileup(region = nil, beg = nil, end_: nil, maxcnt: nil, &block)
      check_closed
      if block_given?
        Pileup.open(self, region:, beg:, end_: end_, maxcnt: maxcnt) do |piter|
          piter.each(&block)
        end
        self
      else
        piter = Pileup.new(self, region:, beg:, end_: end_, maxcnt: maxcnt)
        piter.to_enum(:each)
      end
    end

    private

    def ensure_index_loaded
      return true if index_loaded?
      return false if @index_load_attempted

      load_index(@index_name)
    end

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

    # Multi-region query implementation
    def query_regions(regions, copy: false, &block)
      if copy
        query_regions_copy(regions, &block)
      else
        query_regions_reuse(regions, &block)
      end
    end

    # Internal: yield a single reused Record over the entire file.
    # The underlying bam1_t is mutated on each iteration for speed.
    def each_record_reuse
      check_closed
      # Each does not always start at the beginning of the file.
      # This is the common behavior of IO objects in Ruby.
      return to_enum(__method__) unless block_given?

      record = Record.new(header)
      loop do
        result = @native.read(header.__send__(:native_handle), record.__send__(:native_handle))
        break if result == -1
        raise ReadError, "Failed to read BAM/SAM record (HTSlib error #{result})" if result < -1

        yield record
      end
      self
    end

    # Internal: yield deep-copied Records so callers may retain them safely.
    def each_record_copy
      check_closed
      return to_enum(__method__) unless block_given?

      record = Record.new(header)
      loop do
        result = @native.read(header.__send__(:native_handle), record.__send__(:native_handle))
        break if result == -1
        raise ReadError, "Failed to read BAM/SAM record (HTSlib error #{result})" if result < -1

        yield record.dup
      end
      self
    end

    def queryi_reuse(tid, beg, end_, &block)
      return to_enum(__method__, tid, beg, end_) unless block_given?

      qiter = @native.query_interval(tid, beg, end_)
      raise "Failed to query region: #{tid} #{beg} #{end_}" unless qiter

      query_reuse_yield(qiter, &block)
      self
    end

    def queryi_copy(tid, beg, end_, &block)
      return to_enum(__method__, tid, beg, end_) unless block_given?

      qiter = @native.query_interval(tid, beg, end_)
      raise "Failed to query region: #{tid} #{beg} #{end_}" unless qiter

      query_copy(qiter, &block)
      self
    end

    def querys_reuse(region, &block)
      return to_enum(__method__, region) unless block_given?

      qiter = @native.query_region(header.__send__(:native_handle), region)
      raise "Failed to query region: #{region}" unless qiter

      query_reuse_yield(qiter, &block)
      self
    end

    def querys_copy(region, &block)
      return to_enum(__method__, region) unless block_given?

      qiter = @native.query_region(header.__send__(:native_handle), region)
      raise "Failed to query region: #{region}" unless qiter

      query_copy(qiter, &block)
      self
    end

    # Internal: reused-Record iterator over a query iterator.
    def query_reuse_yield(qiter)
      record = Record.new(header)
      begin
        while (slen = qiter.next(record.__send__(:native_handle))) >= 0
          yield record
        end
        raise if slen < -1
      ensure
        qiter.close
      end
    end

    def query_copy(qiter)
      record = Record.new(header)
      loop do
        slen = qiter.next(record.__send__(:native_handle))
        break if slen == -1
        raise if slen < -1

        yield record.dup
      end
    ensure
      qiter.close
    end

    # Multi-region query using sequential single-region queries
    # Note: This is a fallback implementation. Ideally we would use sam_itr_regarray
    # but there seem to be issues with the multi-region iterator in the current setup.
    def query_regions_reuse(regions, &block)
      return to_enum(__method__, regions) unless block_given?

      regions.each do |region|
        querys_reuse(region, &block)
      end
      self
    end

    # Multi-region query with copied Records using sequential queries
    def query_regions_copy(regions, &block)
      return to_enum(__method__, regions) unless block_given?

      regions.each do |region|
        querys_copy(region, &block)
      end
      self
    end
  end
end
