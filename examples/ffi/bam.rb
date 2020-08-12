require 'htslib'

htf = HTS::FFI.hts_open("poo.sort.bam", "r")
idx = HTS::FFI.sam_index_load(htf, "poo.sort.bam")
hdr = HTS::FFI.sam_hdr_read(htf)
b   = HTS::FFI.bam_init1

HTS::FFI.sam_read1(htf, hdr, b)
puts b[:core][:flag]