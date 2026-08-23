#!/usr/bin/env ruby
# frozen_string_literal: true
#
# ruby-htslib benchmark for the paper's performance table.
# Mirrors the workloads in bench_c.c and bench.cr exactly, run against the
# same synthetic fixture files (bench.bam / bench.bcf).
#
# Usage: bundle exec ruby -Ilib ../bench/bench_ruby.rb <bench.bam> <bench.bcf> [region]

require "htslib"

bam_path = ARGV[0] or abort "usage: bench_ruby.rb <bench.bam> <bench.bcf> [region]"
bcf_path = ARGV[1] or abort "usage: bench_ruby.rb <bench.bam> <bench.bcf> [region]"
region = ARGV[2] || "chr1:500000-600000"

def report(label, seconds, n)
  printf("%-52s %10.4fs  %14.0f records/s (n=%d)\n", label, seconds, n / seconds, n)
end

puts "ruby-htslib version: #{HTS::VERSION rescue 'unknown'}"
puts "BAM: #{bam_path}"
puts "BCF: #{bcf_path}"
puts "Region: #{region}\n\n"

# 1. Sequential BAM record scan (reuse: false conversion, minimal work)
HTS::Bam.open(bam_path) do |bam|
  n = 0
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  bam.each { |_rec| n += 1 }
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  report("Sequential BAM record scan", t1 - t0, n)
end

# 2. BAM scan w/ flag + coordinate access
HTS::Bam.open(bam_path) do |bam|
  n = 0
  acc = 0
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  bam.each do |rec|
    acc += rec.flag_value
    acc += rec.tid
    acc += rec.pos
    n += 1
  end
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  report("BAM scan w/ flag+coord access", t1 - t0, n)
end

# 3. Sequential BCF record scan
HTS::Bcf.open(bcf_path) do |bcf|
  n = 0
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  bcf.each { |_rec| n += 1 }
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  report("Sequential BCF record scan", t1 - t0, n)
end

# 4. FORMAT/GT integer traversal (allele iterator, no string allocation)
HTS::Bcf.open(bcf_path) do |bcf|
  n = 0
  acc = 0
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  bcf.each do |rec|
    rec.format.each_genotype do |_sample, genotype|
      genotype.each_allele { |allele, _phased, _missing| acc += allele.to_i }
    end
    n += 1
  end
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  report("FORMAT/GT integer traversal", t1 - t0, n)
end

# 5. FORMAT/GT string conversion (allocating convenience path)
HTS::Bcf.open(bcf_path) do |bcf|
  n = 0
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  bcf.each do |rec|
    rec.format.genotype_strings
    n += 1
  end
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  report("FORMAT/GT string conversion", t1 - t0, n)
end

# 6. FORMAT/DP + AD traversal
HTS::Bcf.open(bcf_path) do |bcf|
  n = 0
  acc = 0
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  bcf.each do |rec|
    format = rec.format
    format.each_i32("DP") { |_sample, value| acc += value.to_i }
    format.each_i32_vector("AD") { |_sample, values| values.each { |v| acc += v.to_i } }
    n += 1
  end
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  report("FORMAT/DP+AD traversal", t1 - t0, n)
end

# 7. Indexed region query (first + repeated x20)
HTS::Bam.open(bam_path) do |bam|
  n = 0
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  bam.query(region) { |_rec| n += 1 }
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  report("Indexed region query (first)", t1 - t0, n)

  repeats = 20
  n2 = 0
  t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  repeats.times do
    bam.query(region) { |_rec| n2 += 1 }
  end
  t3 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  report("Indexed region query (repeated x20, per-call avg)", (t3 - t2) / repeats, n2 / repeats)
end

# 8. Pileup base counting (region-scoped, matching min_base_quality=13 used in the C baseline)
HTS::Bam.open(bam_path) do |bam|
  columns = 0
  total_bases = 0
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  HTS::Bam::Pileup.open(bam, region: region) do |pileup|
    pileup.each_base_counts(min_base_quality: 13, min_mapping_quality: 0) do |_tid, _pos, counts|
      columns += 1
      total_bases += counts[0] # counts[0] == :depth per BASE_COUNT_FIELDS ordering
    end
  end
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  report("Pileup base counting", t1 - t0, columns)
  puts format("%-52s columns=%d bases_counted=%d", "  (pileup detail)", columns, total_bases)
end
