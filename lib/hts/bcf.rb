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

    def initialize(file_name, mode = "r", index: nil, threads: nil,
                   create_index: false)
      if block_given?
        message = "HTS::Bcf.new() dose not take block; Please use HTS::Bcf.open() instead"
        raise message
      end

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      @file_name  = file_name
      @index_name = index
      @mode       = mode
      @hts_file   = LibHTS.hts_open(@file_name, mode)

      raise Errno::ENOENT, "Failed to open #{@file_name}" if @hts_file.null?

      set_threads(threads) if threads

      return if @mode[0] == "w"

      @header = Bcf::Header.new(@hts_file)
      create_index(index) if create_index
      @idx = load_index(index)
      @start_position = tell
      super # do nothing
    end

    def create_index(index_name = nil)
      check_closed

      warn "Create index for #{@file_name} to #{index_name}"
      if index_name
        LibHTS.bcf_index_build2(@file_name, index_name, -1)
      else
        LibHTS.bcf_index_build(@file_name, -1)
      end
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

    def write_header
      check_closed

      @header = header.dup
      LibHTS.hts_set_fai_filename(header, @file_name)
      LibHTS.bcf_hdr_write(@hts_file, header)
    end

    def write(var)
      check_closed

      var_dup = var.dup
      LibHTS.bcf_write(@hts_file, header, var_dup) > 0 || raise
    end

    # Close the current file.

    def nsamples
      check_closed

      header.nsamples
    end

    def samples
      check_closed

      header.samples
    end

    # Iterate over each record.
    # Generate a new Record object each time.
    # Slower than each.
    def each_copy
      check_closed

      return to_enum(__method__) unless block_given?

      while LibHTS.bcf_read(@hts_file, header, bcf1 = LibHTS.bcf_init) != -1
        record = Record.new(bcf1, header)
        yield record
      end
      self
    end

    # Iterate over each record.
    # Record object is reused.
    # Faster than each_copy.
    def each
      check_closed

      return to_enum(__method__) unless block_given?

      bcf1 = LibHTS.bcf_init
      record = Record.new(bcf1, header)
      yield record while LibHTS.bcf_read(@hts_file, header, bcf1) != -1
      self
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
      if key
        ary = map { |r| r.info(key) }
      else
        raise NotImplementedError
        # ary = each_copy.map { |r| r.info }
        # ary = map { |r| r.info.clone }
      end
      seek(position)
      ary
    end

    def format(key = nil)
      check_closed
      position = tell
      if key
        ary = map { |r| r.format(key) }
      else
        raise NotImplementedError
        # ary = each_copy.map { |r| r.format }
        # ary = map { |r| r.format.clone }
      end
      seek(position)
      ary
    end

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
      return to_enum(__method__) unless block

      each do |r|
        yield r.info(key)
      end
    end

    def each_format(key)
      check_closed
      return to_enum(__method__) unless block

      each do |r|
        yield r.format(key)
      end
    end
  end
end
