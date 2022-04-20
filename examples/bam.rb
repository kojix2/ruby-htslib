# frozen_string_literal: true

require "htslib"

bam_path = File.expand_path("../test/fixtures/moo.sam", __dir__)

HTS::Bam.open(bam_path) do |bam|
  bam.each do |r|
    pp name: r.qname,
       flag: r.flag,
       chr: r.chrom,
       pos: r.start + 1,
       mqual: r.mapq,
       cigar: r.cigar.to_s,
       mchr: r.mate_chrom,
       mpos: r.mpos + 1,
       isize: r.insert_size,
       seq: r.seq,
       qual: r.base_qualities.map { |i| (i + 33).chr }.join,
       tag_MC: r.tag("MC")
  end
end
