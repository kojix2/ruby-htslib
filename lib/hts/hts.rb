# frozen_string_literal: true

require_relative "../htslib"

module HTS
  # A base class for hts files.
  class Hts
    def initialize(*args)
      # do nothing
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

    private

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
      if @start_position
        r = seek(@start_position)
        raise "Failed to rewind: #{r}" if r < 0

        tell
      else
        raise "Cannot rewind: no start position"
      end
    end

    def check_closed
      raise IOError, "closed stream" if closed?
    end
  end
end
