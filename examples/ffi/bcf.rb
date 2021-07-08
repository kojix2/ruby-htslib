# frozen_string_literal: true

require "htslib"

bcf_path = File.expand_path("../../htslib/test/tabix/vcf_file.bcf", __dir__)

htf = HTS::LibHTS.hts_open(bcf_path, "r")
hdr = HTS::LibHTS.bcf_hdr_read(htf)
c = HTS::LibHTS.bcf_init
HTS::LibHTS.bcf_read(htf, hdr, c)
HTS::LibHTS.bcf_unpack(c, 15)
