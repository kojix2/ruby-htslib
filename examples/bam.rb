# frozen_string_literal: true

require 'htslib'

path = ARGV[0]
if path.nil?
  warn "bam file not found"
  warn "e.g.  ruby examples/bam.rb test/fixtures/poo.sort.bam"
  exit
end

bam_path = File.expand_path(path)

bam = HTS::Bam.new(bam_path)

bam.each do |r|
  p name: r.qname,
    flag: r.flag,
    start: r.start + 1,
    mpos: r.mate_pos + 1,
    mqual: r.mapping_quality,
    seq: r.sequence,
    cigar: r.cigar.to_s,
    qual: r.base_qualities.map { |i| (i + 33).chr }.join
end
