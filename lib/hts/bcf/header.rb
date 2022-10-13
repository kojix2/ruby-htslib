# frozen_string_literal: true

require_relative "header/record"

module HTS
  class Bcf < Hts
    # A class for working with VCF records.
    class Header
      def initialize(arg = nil)
        case arg
        when LibHTS::HtsFile
          @bcf_hdr = LibHTS.bcf_hdr_read(arg)
        when LibHTS::BcfHdr
          @bcf_hdr = arg
        when nil
          @bcf_hdr = LibHTS.bcf_hdr_init("w")
        else
          raise TypeError, "Invalid argument"
        end
      end

      def struct
        @bcf_hdr
      end

      def to_ptr
        @bcf_hdr.to_ptr
      end

      def get_version
        LibHTS.bcf_hdr_get_version(@bcf_hdr)
      end

      def set_version(version)
        LibHTS.bcf_hdr_set_version(@bcf_hdr, version)
      end

      def nsamples
        LibHTS.bcf_hdr_nsamples(@bcf_hdr)
      end

      def samples
        # bcf_hdr_id2name is macro function
        @bcf_hdr[:samples]
          .read_array_of_pointer(nsamples)
          .map(&:read_string)
      end

      def add_sample(sample, sync: true)
        LibHTS.bcf_hdr_add_sample(@bcf_hdr, sample)
        self.sync if sync
      end

      def merge(hdr)
        LibHTS.bcf_hdr_merge(@bcf_hdr, hdr.struct)
      end

      def sync
        LibHTS.bcf_hdr_sync(@bcf_hdr)
      end

      def read_bcf(fname)
        LibHTS.bcf_hdr_set(@bcf_hdr, fname)
      end

      def append(line)
        LibHTS.bcf_hdr_append(@bcf_hdr, line)
      end

      def delete(bcf_hl_type, key) # FIXME
        type = bcf_hl_type_to_int(bcf_hl_type)
        LibHTS.bcf_hdr_remove(@bcf_hdr, type, key)
      end

      def get_hrec(bcf_hl_type, key, value, str_class = nil)
        type = bcf_hl_type_to_int(bcf_hl_type)
        hrec = LibHTS.bcf_hdr_get_hrec(@bcf_hdr, type, key, value, str_class)
        Header::Record.new(hrec)
      end

      def to_s
        kstr = LibHTS::KString.new
        raise "Failed to get header string" unless LibHTS.bcf_hdr_format(@bcf_hdr, 0, kstr)

        kstr[:s]
      end

      private

      def bcf_hl_type_to_int(bcf_hl_type)
        return bcf_hl_type if bcf_hl_type.is_a?(Integer)

        case bcf_hl_type.to_s.upcase
        when "FILTER", "FIL"
          LibHTS::BCF_HL_FLT
        when "INFO"
          LibHTS::BCF_HL_INFO
        when "FORMAT", "FMT"
          LibHTS::BCF_HL_FMT
        when "CONTIG", "CTG"
          LibHTS::BCF_HL_CTG
        when "STRUCT", "STR", "STRUCTURE"
          LibHTS::BCF_HL_STR
        when "GENOTYPE", "GEN"
          LibHTS::BCF_HL_GEN
        else
          raise TypeError, "Invalid argument"
        end
      end

      def initialize_copy(orig)
        @bcf_hdr = LibHTS.bcf_hdr_dup(orig.struct)
      end
    end
  end
end
