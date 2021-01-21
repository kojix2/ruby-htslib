# frozen_string_literal: true

require 'htslib'

bam_path = ARGV[0] || File.expand_path('../test/assets/poo.sort.bam', __dir__)

bam = HTS::Bam.new(bam_path)

bam.each do |aln|
  p name: aln.qname,
    flag: aln.flag,
    pos: aln.pos + 1,
    mpos: aln.mate_pos + 1,
    mqual: aln.mapping_quality,
    seq: aln.sequence,
    cigar: aln.cigar.to_s,
    qual: aln.base_qualities.map { |i| (i + 33).chr }.join
end
