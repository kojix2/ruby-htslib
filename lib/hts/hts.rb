require_relative "../htslib"

module HTS
  class Hts
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
  end
end
