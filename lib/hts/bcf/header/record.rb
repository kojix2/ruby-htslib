# frozen_string_literal: true

module HTS
  class Bcf < Hts
    class Header
      class Record
        def initialize(arg = nil)
          case arg
          when LibHTS::BcfHrec
            @bcf_hrec = arg
          else
            raise TypeError, "Invalid argument"
          end
        end

        def struct
          @bcf_hrec
        end

        def add_key(key)
          LibHTS.bcf_hrec_add_key(@bcf_hrec, key, key.length)
        end
        
        def set_value(i, val, quote: true)
          is_quoted = quote ? 1 : 0
          LibHTS.bcf_hrec_set_val(@bcf_hrec, i, val, val.length, is_quoted)
        end

        def find_key(key)
          LibHTS.bcf_hrec_find_key(@bcf_hrec, key)
        end
        
        def to_s
          kstr = LibHTS::KString.new
          LibHTS.bcf_hrec_format(@bcf_hrec, kstr)
          kstr[:s]
        end

        private

        def initialize_copy(orig)
          @bcf_hrec = LibHTS.bcf_hrec_dup(orig.struct)
        end
      end
    end
  end
end
