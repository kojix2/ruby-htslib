# frozen_string_literal: true

require_relative "../htslib"

require_relative "hts"

module HTS
  class Tbx < Hts
    include Enumerable

    attr_reader :file_name

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

    def initialize(file_name, threads: nil)
      if block_given?
        message = "HTS::Tbx.new() dose not take block; Please use HTS::Tbx.open() instead"
        raise message
      end

      @file_name = file_name

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      @mode     = "r"
      @hts_file = LibHTS.hts_open(@file_name, @mode)

      raise Errno::ENOENT, "Failed to open #{@file_name}" if @hts_file.null?

      if threads&.> 0
        r = LibHTS.hts_set_threads(@hts_file, threads)
        raise "Failed to set number of threads: #{threads}" if r < 0
      end
    end
  end
end
