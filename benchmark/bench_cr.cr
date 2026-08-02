# hts.cr benchmark for the paper's performance table.
# Mirrors the workloads in bench_c.c and bench_ruby.rb exactly, run against
# the same synthetic fixture files (bench.bam / bench.bcf).
#
# Build (set CRYSTAL_PATH to the hts.cr src directory when it is not installed):
#   CRYSTAL_PATH=../../hts.cr/src crystal build --release -o bench_cr bench_cr.cr
# Usage: ./bench_cr <bench.bam> <bench.bcf> [region]

require "hts"

bam_path = ARGV[0]? || abort "usage: bench_cr <bench.bam> <bench.bcf> [region]"
bcf_path = ARGV[1]? || abort "usage: bench_cr <bench.bam> <bench.bcf> [region]"
region = ARGV[2]? || "chr1:500000-600000"

def report(label : String, seconds : Float64, n : Int)
  rate = n / seconds
  printf("%-52s %10.4fs  %14.0f records/s (n=%d)\n", label, seconds, rate, n)
end

puts "hts.cr version: #{HTS::VERSION}"
puts "BAM: #{bam_path}"
puts "BCF: #{bcf_path}"
puts "Region: #{region}\n\n"

# 1. Sequential BAM record scan
HTS::Bam.open(bam_path) do |bam|
  n = 0
  t0 = Time.monotonic
  bam.each { |_rec| n += 1 }
  t1 = Time.monotonic
  report("Sequential BAM record scan", (t1 - t0).total_seconds, n)
end

# 2. BAM scan w/ flag + coordinate access
HTS::Bam.open(bam_path) do |bam|
  n = 0
  acc = 0_i64
  t0 = Time.monotonic
  bam.each do |rec|
    acc += rec.flag.value
    acc += rec.tid
    acc += rec.pos
    n += 1
  end
  t1 = Time.monotonic
  report("BAM scan w/ flag+coord access", (t1 - t0).total_seconds, n)
end

# 3. Sequential BCF record scan
HTS::Bcf.open(bcf_path) do |bcf|
  n = 0
  t0 = Time.monotonic
  bcf.each { |_rec| n += 1 }
  t1 = Time.monotonic
  report("Sequential BCF record scan", (t1 - t0).total_seconds, n)
end

# 4. FORMAT/GT integer traversal (raw genotype ints, no string allocation)
HTS::Bcf.open(bcf_path) do |bcf|
  n = 0
  acc = 0_i64
  t0 = Time.monotonic
  bcf.each do |rec|
    if gts = rec.format.genotypes
      gts.each { |g| acc += g }
    end
    n += 1
  end
  t1 = Time.monotonic
  report("FORMAT/GT integer traversal", (t1 - t0).total_seconds, n)
end

# 5. FORMAT/GT string conversion (allocating convenience path)
HTS::Bcf.open(bcf_path) do |bcf|
  n = 0
  t0 = Time.monotonic
  bcf.each do |rec|
    rec.format.get_string("GT")
    n += 1
  end
  t1 = Time.monotonic
  report("FORMAT/GT string conversion", (t1 - t0).total_seconds, n)
end

# 6. FORMAT/DP + AD traversal
HTS::Bcf.open(bcf_path) do |bcf|
  n = 0
  acc = 0_i64
  t0 = Time.monotonic
  bcf.each do |rec|
    format = rec.format
    if dp = format.get_int("DP")
      dp.each { |v| acc += v }
    end
    if ad = format.get_int("AD")
      ad.each { |v| acc += v }
    end
    n += 1
  end
  t1 = Time.monotonic
  report("FORMAT/DP+AD traversal", (t1 - t0).total_seconds, n)
end

# 7. Indexed region query (first + repeated x20)
HTS::Bam.open(bam_path) do |bam|
  n = 0
  t0 = Time.monotonic
  bam.query(region) { |_rec| n += 1 }
  t1 = Time.monotonic
  report("Indexed region query (first)", (t1 - t0).total_seconds, n)

  repeats = 20
  n2 = 0
  t2 = Time.monotonic
  repeats.times do
    bam.query(region) { |_rec| n2 += 1 }
  end
  t3 = Time.monotonic
  report("Indexed region query (repeated x20, per-call avg)", (t3 - t2).total_seconds / repeats, n2 // repeats)
end

# 8. Pileup base counting (region-scoped, min_base_quality=13 to match the C/Ruby baselines)
HTS::Bam.open(bam_path) do |bam|
  columns = 0
  total_bases = 0_i64
  min_base_q = 13_u8
  t0 = Time.monotonic
  HTS::Bam::Pileup.open(bam, region) do |pileup|
    pileup.each do |col|
      columns += 1
      col.alignments.each do |aln|
        next if aln.del? || aln.refskip?
        qual = aln.base_qual
        next if qual.nil? || qual < min_base_q
        total_bases += 1
      end
    end
  end
  t1 = Time.monotonic
  report("Pileup base counting", (t1 - t0).total_seconds, columns)
  printf("%-52s columns=%d bases_counted=%d\n", "  (pileup detail)", columns, total_bases)
end
