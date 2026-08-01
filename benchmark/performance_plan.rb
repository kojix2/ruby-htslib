# frozen_string_literal: true

require "tempfile"
require "csv"
require_relative "../lib/htslib"

iterations = Integer(ENV.fetch("ITERATIONS", "100000"))
scan_iterations = Integer(ENV.fetch("SCAN_ITERATIONS", "100"))

GC.measure_total_time = true if GC.respond_to?(:measure_total_time=)
RESULTS = []

at_exit do
  output = ENV["BENCHMARK_CSV"]
  next unless output

  CSV.open(output, "w") do |csv|
    csv << %w[label seconds allocated_objects malloc_delta_bytes gc_milliseconds rss_delta_kib]
    RESULTS.each { |row| csv << row.values_at(*%i[label seconds objects malloc_delta gc_ms rss_delta]) }
  end
end

def resident_kb
  status = "/proc/self/status"
  return File.foreach(status).find { |line| line.start_with?("VmRSS:") }.split[1].to_i if File.exist?(status)

  IO.popen(["ps", "-o", "rss=", "-p", Process.pid.to_s], &:read).to_i
end

def measure(label)
  GC.start
  allocations_before = GC.stat(:total_allocated_objects)
  malloc_before = GC.stat(:malloc_increase_bytes)
  gc_time_before = GC.stat(:time)
  rss_before = resident_kb
  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  allocations = GC.stat(:total_allocated_objects) - allocations_before
  malloc_delta = GC.stat(:malloc_increase_bytes) - malloc_before
  gc_time = GC.stat(:time) - gc_time_before
  rss_delta = resident_kb - rss_before
  RESULTS << { label:, seconds: elapsed, objects: allocations, malloc_delta:, gc_ms: gc_time, rss_delta: }
  puts format("%-28s %8.4fs %11d obj %11d B mallocΔ %7.2fms GC %+8d KiB RSS",
              label, elapsed, allocations, malloc_delta, gc_time, rss_delta)
end

Tempfile.create(["ruby_htslib_performance", ".vcf"]) do |file|
  file.write <<~VCF
    ##fileformat=VCFv4.3
    ##contig=<ID=1,length=100>
    ##INFO=<ID=IV,Number=.,Type=Integer,Description="Integer vector">
    ##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
    ##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Depth">
    ##FORMAT=<ID=AD,Number=R,Type=Integer,Description="Allele depths">
    ##FORMAT=<ID=GL,Number=G,Type=Float,Description="Likelihoods">
    #CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tS1\tS2
    1\t10\t.\tA\tC\t.\tPASS\tIV=1,2,3,4\tGT:DP:AD:GL\t0/1:10:4,6:-2,-1,-3\t1/1:20:0,20:-4,-2,-1
  VCF
  file.flush

  HTS::Bcf.open(file.path) do |bcf|
    record = bcf.first
    info = record.info
    format = record.format

    puts "Iterations: #{iterations}"
    measure("INFO owning array") { iterations.times { info.get("IV") } }
    measure("DP owning array") { iterations.times { format.get("DP") } }
    measure("DP scalar iterator") do
      iterations.times { format.each_i32("DP") { |_sample, _value| } }
    end
    measure("AD owning nested arrays") { iterations.times { format.get("AD") } }
    measure("AD borrowed iterator") do
      iterations.times { format.each_i32_vector("AD") { |_sample, values| values.each { |_value| } } }
    end
    measure("GL owning native bulk") { iterations.times { format.get("GL") } }
    measure("GL borrowed iterator") do
      iterations.times { format.each_f32_vector("GL") { |_sample, values| values.each { |_value| } } }
    end
    measure("GT owning strings") { iterations.times { format.genotype_strings } }
    measure("GT allele iterator") do
      iterations.times do
        format.each_genotype do |_sample, genotype|
          genotype.each_allele { |_allele, _phased, _missing| }
        end
      end
    end

    records = Array.new(100, record)
    measure("BCF Ruby batch filter") { iterations.times { records.select { |r| r.rid == 0 } } }
    measure("BCF native batch filter") do
      iterations.times { HTS::Bcf.filter_records(records, rid: 0) }
    end
  end
end

bam_path = File.expand_path("../test/fixtures/moo.bam", __dir__)
HTS::Bam.open(bam_path) do |bam|
  record = bam.first.dup
  record.aux.update_array("XA", [-2, 0, 7, 100, 1000], type: "i")

  puts "\nBAM record workloads"
  measure("flag wrapper predicate") { iterations.times { record.flag.unmapped? } }
  measure("flag direct predicate") { iterations.times { record.unmapped? } }
  measure("flag direct FFI field") do
    iterations.times { (record.struct[:core][:flag] & HTS::LibHTS::BAM_FUNMAP) != 0 }
  end
  measure("sequence String") { iterations.times { record.seq } }
  measure("sequence native helper") { iterations.times { HTS::Native.bam_sequence(record.to_ptr.address) } }
  measure("sequence base iterator") { iterations.times { record.each_base { |_base| } } }
  measure("quality Array") { iterations.times { record.qual } }
  measure("quality iterator") { iterations.times { record.each_qual { |_quality| } } }
  measure("quality String") { iterations.times { record.qual_string } }
  measure("AUX B owning Array") { iterations.times { record.aux.get("XA") } }
  measure("AUX B iterator") { iterations.times { record.aux.each_array("XA") { |_value| } } }
  measure("AUX packed tag IDs") { iterations.times { record.aux.each_tag_id { |_tag_id, _value| } } }

  records = Array.new(100, record)
  measure("BAM Ruby batch filter") { iterations.times { records.select { |r| r.mapq >= 20 && !r.secondary? } } }
  measure("BAM native batch filter") do
    iterations.times do
      HTS::Bam.filter_records(records, min_mapq: 20, excluded_flags: HTS::LibHTS::BAM_FSECONDARY)
    end
  end
end

tabix_path = File.expand_path("../test/fixtures/test.vcf.gz", __dir__)
HTS::Tabix.open(tabix_path) do |tabix|
  puts "\nTabix row workloads (#{scan_iterations} scans)"
  measure("Tabix split fields") do
    scan_iterations.times { tabix.each_fields("poo:4020-4022") { |_fields| } }
  end
  measure("Tabix raw line") do
    scan_iterations.times { tabix.each_line("poo:4020-4022") { |_line| } }
  end
  measure("Tabix selected fields") do
    scan_iterations.times { tabix.each_selected_fields("poo:4020-4022", 0, 1, 3) { |_fields| } }
  end
end

puts "\nMpileup workloads (#{scan_iterations} scans, two inputs)"
measure("mpileup depth") do
  scan_iterations.times do
    HTS::Bam::Mpileup.open([bam_path, bam_path]) do |mpileup|
      mpileup.each_depth { |_tid, _pos, _depths| }
    end
  end
end
measure("mpileup base counts") do
  scan_iterations.times do
    HTS::Bam::Mpileup.open([bam_path, bam_path]) do |mpileup|
      mpileup.each_base_counts { |_tid, _pos, _counts_by_input| }
    end
  end
end

HTS::Bam.open(bam_path) do |bam|
  puts "\nPileup workloads (#{scan_iterations} scans, native=#{HTS::Native::AVAILABLE})"
  measure("pileup columns") do
    scan_iterations.times do
      bam.rewind
      HTS::Bam::Pileup.open(bam) { |pileup| pileup.each { |_column| } }
    end
  end
  measure("pileup depth") do
    scan_iterations.times do
      bam.rewind
      HTS::Bam::Pileup.open(bam) { |pileup| pileup.each_depth { |_tid, _pos, _depth| } }
    end
  end
  measure("pileup borrowed views") do
    scan_iterations.times do
      bam.rewind
      HTS::Bam::Pileup.open(bam) { |pileup| pileup.each_view { |column| column.each { |_entry| } } }
    end
  end
  measure("pileup base counts") do
    scan_iterations.times do
      bam.rewind
      HTS::Bam::Pileup.open(bam) { |pileup| pileup.each_base_counts { |_tid, _pos, _counts| } }
    end
  end
end
