# frozen_string_literal: true

require_relative "../htslib"

module HTS
  class Hts
    def struct
      @hts_file
    end

    def to_ptr
      @hts_file.to_ptr
    end

    def format
      LibHTS.hts_get_format(@hts_file)[:format].to_s
    end

    def format_version
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
      r = seek(@start_position) if @start_position
      raise "Failed to rewind: #{r}" if r < 0

      r
    end
  end
end
