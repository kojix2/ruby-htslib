# frozen_string_literal: true

require 'htslib'

bcf_path = File.expand_path('../../htslib/test/tabix/vcf_file.bcf', __dir__)

htf = HTS::FFI.hts_open(bcf_path, 'r')
hdr = HTS::FFI.bcf_hdr_read(htf)
c = HTS::FFI.bcf_init
HTS::FFI.bcf_read(htf, hdr, c)
