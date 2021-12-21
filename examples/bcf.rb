# frozen_string_literal: true

require "htslib"

path = ARGV[0]
if path.nil?
  warn "bcf file not found"
  warn "e.g.  ruby examples/bcf.rb htslib/test/tabix/vcf_file.bcf"
  exit
end

bcf_path = File.expand_path(path)

bcf = HTS::Bcf.new(bcf_path)

bcf.each do |r|
  p chrom: r.chrom,
    pos: r.pos,
    id: r.id,
    qual: r.qual.round(2),
    ref: r.ref,
    alt: r.alt,
    filter: r.filter
end

bcf.close
