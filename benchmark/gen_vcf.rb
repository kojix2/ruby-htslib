#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Generates a deterministic synthetic VCF file for benchmarking.
# Pure text generation -- does not use ruby-htslib or hts.cr.

N_SITES   = Integer(ENV.fetch("N_SITES", "50000"))
N_SAMPLES = Integer(ENV.fetch("N_SAMPLES", "20"))
REF_LEN   = Integer(ENV.fetch("REF_LEN", "2000000"))
SEED      = Integer(ENV.fetch("SEED", "42"))

abort "N_SITES must be positive" unless N_SITES.positive?
abort "N_SAMPLES must be positive" unless N_SAMPLES.positive?
abort "REF_LEN must be at least N_SITES" if REF_LEN < N_SITES

srand(SEED)
BASES = %w[A C G T].freeze
GTS   = ["0/0", "0/1", "1/1", "1/0"].freeze

samples = Array.new(N_SAMPLES) { |i| "S#{i + 1}" }

puts "##fileformat=VCFv4.3"
puts "##contig=<ID=chr1,length=#{REF_LEN}>"
puts '##INFO=<ID=DP,Number=1,Type=Integer,Description="Total depth">'
puts '##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">'
puts '##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Depth">'
puts '##FORMAT=<ID=AD,Number=R,Type=Integer,Description="Allele depths">'
puts '##FORMAT=<ID=GL,Number=G,Type=Float,Description="Likelihoods">'
puts (%w[#CHROM POS ID REF ALT QUAL FILTER INFO FORMAT] + samples).join("\t")

N_SITES.times do |i|
  # Draw one site from each non-overlapping interval so positions remain
  # sorted and within the declared contig.
  interval_start = i * REF_LEN / N_SITES + 1
  interval_end = (i + 1) * REF_LEN / N_SITES
  pos = rand(interval_start..interval_end)
  ref = BASES.sample
  alt = (BASES - [ref]).sample
  total_dp = rand(50..500)
  fields = samples.map do
    gt = GTS.sample
    dp = rand(5..60)
    ad_ref = rand(0..dp)
    ad_alt = dp - ad_ref
    gl = [-(rand * 4).round(2), -(rand * 2).round(2), -(rand * 4).round(2)]
    "#{gt}:#{dp}:#{ad_ref},#{ad_alt}:#{gl.join(',')}"
  end
  puts [
    "chr1", pos, ".", ref, alt, ".", "PASS", "DP=#{total_dp}", "GT:DP:AD:GL", *fields
  ].join("\t")
end
