#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Generates a deterministic synthetic SAM file for benchmarking.
# Pure text generation -- does not use ruby-htslib or hts.cr, so the
# resulting fixture is not biased toward either binding under test.

N_READS  = Integer(ENV.fetch("N_READS", "300000"))
REF_LEN  = Integer(ENV.fetch("REF_LEN", "2000000"))
READ_LEN = 100
SEED     = Integer(ENV.fetch("SEED", "42"))

abort "N_READS must be non-negative" if N_READS.negative?
abort "REF_LEN must be greater than READ_LEN" if REF_LEN <= READ_LEN

srand(SEED)
BASES = %w[A C G T].freeze

puts "@HD\tVN:1.6\tSO:coordinate"
puts "@SQ\tSN:chr1\tLN:#{REF_LEN}"

positions = Array.new(N_READS) { rand(0..(REF_LEN - READ_LEN - 1)) }.sort

positions.each_with_index do |pos, i|
  seq = Array.new(READ_LEN) { BASES.sample }.join
  qual = Array.new(READ_LEN) { (rand(0..40) + 33).chr }.join
  # Single-end records: ~2% reverse strand and ~1% secondary.
  flag = 0
  # Drawing only on even records preserves the fixture's deterministic random
  # stream; a 4% conditional rate gives ~2% overall.
  flag |= 0x10 if i.even? && rand < 0.04
  flag |= 0x100 if i % 97 == 0
  mapq = 30 + rand(0..30)
  nm = rand(0..3)
  puts [
    "read#{i}",
    flag,
    "chr1",
    pos + 1, # SAM is 1-based
    mapq,
    "#{READ_LEN}M",
    "*",
    0,
    0,
    seq,
    qual,
    "NM:i:#{nm}",
  ].join("\t")
end
