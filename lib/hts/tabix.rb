require_relative "../htslib"

require_relative "hts"

module HTS
  class Tabix < Hts
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
        message = "HTS::Tabix.new() dose not take block; Please use HTS::Tabix.open() instead"
        raise message
      end

      @file_name = file_name

      # NOTE: Do not check for the existence of local files, since file_names may be remote URIs.

      @mode     = "r"
      @hts_file = LibHTS.hts_open(@file_name, @mode)

      if threads&.> 0
        r = LibHTS.hts_set_threads(@hts_file, threads)
        raise "Failed to set number of threads: #{threads}" if r < 0
      end
    end

    def close
      LibHTS.hts_close(@hts_file)
      @hts_file = nil
    end

    def closed?
      @hts_file.nil?
    end
  end
end
