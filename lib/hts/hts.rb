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

    def seek(offset)
      if format == "cram"
        LibHTS.cram_seek(@hts_file[:fp][:cram], offset, IO::SEEK_SET)
      else
        LibHTS.bgzf_seek(@hts_file[:fp][:bgzf], offset, IO::SEEK_SET)
      end
    end

    def tell
      if format == "cram"
        LibHTS.cram_tell(@hts_file[:fp][:cram])
      else
        LibHTS.bgzf_tell(@hts_file[:fp][:bgzf])
      end
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
  end
end
