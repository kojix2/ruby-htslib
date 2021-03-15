# frozen_string_literal: true

require 'htslib'

bam_path = File.expand_path(ARGV[0])

bam = HTS::Bam.new(bam_path)

bam.each do |aln|
  p name: aln.qname,
    flag: aln.flag,
    start: aln.start + 1,
    mpos: aln.mate_pos + 1,
    mqual: aln.mapping_quality,
    seq: aln.sequence,
    cigar: aln.cigar.to_s,
    qual: aln.base_qualities.map { |i| (i + 33).chr }.join
end
