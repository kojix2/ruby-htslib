# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Fai
    def self.open(path)
      fai = self.new(path)
      if block_given?
        yield(fai)
        fai.close
      else
        fai
      end
    end

    def initialize(path)
      @path = File.expand_path(path)
      @path.delete_suffix!(".fai")
      if File.exist?(@path + ".fai")
        FFI.fai_build(@path)
      end
      @fai = FFI.fai_load(@path)
      # at_exit{FFI.fai_destroy(@fai)}
    end

    def [](region)
      
    end

    def nseqs; end

    def include?; end

    # __iter__
  end
end
