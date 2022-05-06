# frozen_string_literal: true

require "htslib"

bam_path = (ARGV[0] || File.expand_path("../test/fixtures/moo.sam", __dir__))

HTS::Bam.open(bam_path) do |bam|
  bam.each do |r|
    pp name: r.qname,
       flag: r.flag,
       chrm: r.chrom,
       strt: r.pos + 1,
       mapq: r.mapq,
       cigr: r.cigar.to_s,
       mchr: r.mate_chrom,
       mpos: r.mpos + 1,
       isiz: r.isize,
       seqs: r.seq,
       qual: r.qual.map { |i| (i + 33).chr }.join,
       MC: r.aux("MC")
  end
end
