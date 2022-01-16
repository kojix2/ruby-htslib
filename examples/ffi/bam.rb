# frozen_string_literal: true

require "htslib"

multi_thread = 4

bam_path = File.expand_path("../../test/fixtures/poo.sort.bam", __dir__)

htf = HTS::LibHTS.hts_open(bam_path, "r")
idx = HTS::LibHTS.sam_index_load(htf, bam_path)
hdr = HTS::LibHTS.sam_hdr_read(htf)

if multi_thread
  thp =HTS::LibHTS::HtsTpool.new
  thp[:pool] = (t = HTS::LibHTS.hts_tpool_init(multi_thread))
  HTS::LibHTS.hts_set_opt(htf, HTS::LibHTS::HtsFmtOption[:HTS_OPT_THREAD_POOL], :pointer, thp)
end

b = HTS::LibHTS.bam_init1

nuc = { 1 => "A", 2 => "C", 4 => "G", 8 => "T", 15 => "N" }

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
  HTS::LibHTS.sam_read1(htf, hdr, b)
  p b[:core].members.zip(b[:core].values)
  p name: b[:data].read_string,
    flag: b[:core][:flag],
    pos: b[:core][:pos] + 1,
    mpos: b[:core][:mpos] + 1,
    mqual: b[:core][:qual],
    seq: HTS::LibHTS.bam_get_seq(b)
                    .read_bytes(b[:core][:l_qseq] / 2)
                    .unpack1("B*")
                    .each_char.each_slice(4)
                    .map { |i| nuc[i.join.to_i(2)] }.join,
    cigar: (HTS::LibHTS.bam_get_cigar(b)
                       .read_array_of_uint32(b[:core][:n_cigar])
                       .map do |i|
                         s = format("%32d", i.to_s(2))
                         [s[0..27].to_i(2), cig[s[28..].to_i(2)]]
                       end),
    qual: HTS::LibHTS.bam_get_qual(b)
                     .read_array_of_uint8(b[:core][:l_qseq])
                     .map { |i| (i + 33).chr }.join
  # HTS::LibHTS.bam_aux2Z(HTS::LibHTS.bam_aux_get(b, "MC"))
end
