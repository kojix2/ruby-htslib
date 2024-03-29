# frozen_string_literal: true

require_relative "../htslib"

module HTS
  # A base class for hts files.
  class Hts
    class << self
      private

      def define_getter(name)
        define_method(name) do
          check_closed
          position = tell
          ary = map(&name)
          seek(position)
          ary
        end
      end

      def define_iterator(name)
        define_method("each_#{name}") do |&block|
          check_closed
          return to_enum(__method__) unless block

          each do |record|
            block.call(record.public_send(name))
          end
          self
        end
      end
    end

    def initialize(*_args)
      raise TypeError, "Can't make instance of HTS abstract class"
    end

    def struct
      @hts_file
    end

    def to_ptr
      @hts_file.to_ptr
    end

    def file_format
      LibHTS.hts_get_format(@hts_file)[:format].to_s
    end

    def file_format_version
      v = LibHTS.hts_get_format(@hts_file)[:version]
      major = v[:major]
      minor = v[:minor]
      if minor == -1
        major.to_s
      else
        "#{major}.#{minor}"
      end
    end

    def close
      return if closed?

      LibHTS.hts_close(@hts_file)
      @hts_file = nil
    end

    def closed?
      @hts_file.nil? || @hts_file.null?
    end

    def fai=(fai)
      check_closed
      LibHTS.hts_set_fai_filename(@hts_file, fai) > 0 || raise
    end

    def set_threads(n = nil)
      if n.nil?
        require "etc"
        n = [Etc.nprocessors - 1, 1].max
      end
      raise TypeError unless n.is_a?(Integer)
      raise ArgumentError, "Number of threads must be positive" if n < 1

      r = LibHTS.hts_set_threads(@hts_file, n)
      raise "Failed to set number of threads: #{threads}" if r < 0

      @nthreads = n
      self
    end

    def seek(offset)
      if @hts_file[:is_cram] == 1
        LibHTS.cram_seek(@hts_file[:fp][:cram], offset, IO::SEEK_SET)
      elsif @hts_file[:is_bgzf] == 1
        LibHTS.bgzf_seek(@hts_file[:fp][:bgzf], offset, IO::SEEK_SET)
      else
        LibHTS.hseek(@hts_file[:fp][:hfile], offset, IO::SEEK_SET)
      end
    end

    def tell
      if @hts_file[:is_cram] == 1
        # LibHTS.cram_tell(@hts_file[:fp][:cram])
        # warn 'cram_tell is not implemented in c htslib'
        nil
      elsif @hts_file[:is_bgzf] == 1
        LibHTS.bgzf_tell(@hts_file[:fp][:bgzf])
      else
        LibHTS.htell(@hts_file[:fp][:hfile])
      end
    end

    def rewind
      raise "Cannot rewind: no start position" unless @start_position

      r = seek(@start_position)
      raise "Failed to rewind: #{r}" if r < 0

      tell
    end

    private

    def check_closed
      raise IOError, "closed stream" if closed?
    end
  end
end
