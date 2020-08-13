require 'htslib'

htf = HTS::FFI.hts_open('poo.sort.bam', 'r')
idx = HTS::FFI.sam_index_load(htf, 'poo.sort.bam')
hdr = HTS::FFI.sam_hdr_read(htf)
b   = HTS::FFI.bam_init1

nuc = { 1 => 'A', 2 => 'C', 4 => 'G', 8 => 'T', 15 => 'N' }

cig = {
  0 => :BAM_CMATCH,
  1 => :BAM_CINS,
  2 => :BAM_CDEL,
  3 => :BAM_CREF_SKIP,
  4 => :BAM_CSOFT_CLIP,
  5 => :BAM_CHARD_CLIP,
  6 => :BAM_CPAD,
  7 => :BAM_CEQUAL,
  8 => :BAM_CDIFF,
  9 => :BAM_CBACK
}

10.times do
  HTS::FFI.sam_read1(htf, hdr, b)
  p b[:core].members.zip(b[:core].values)
  p name: b[:data].read_string,
    flag: b[:core][:flag],
    pos: b[:core][:pos] + 1,
    mpos: b[:core][:mpos] + 1,
    qual: b[:core][:qual],
    seq: HTS::FFI.bam_get_seq(b).read_bytes(b[:core][:l_qseq] / 2).unpack1('B*')
                 .each_char.each_slice(4).map { |i| nuc[i.join.to_i(2)] }.join,
    cigar: HTS::FFI.bam_get_cigar(b).read_array_of_uint32(b[:core][:n_cigar])
                   .map { |i| s = format('%32d', i.to_s(2)); [s[0..27].to_i(2), cig[s[28..-1].to_i(2)]] },
    qual: HTS::FFI.bam_get_qual(b).read_array_of_uint8(b[:core][:l_qseq]).map { |i| (i + 33).chr }.join
end
