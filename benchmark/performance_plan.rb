# frozen_string_literal: true

require "tempfile"
require_relative "../lib/htslib"

iterations = Integer(ENV.fetch("ITERATIONS", "100000"))

def measure(label)
  GC.start
  allocations_before = GC.stat(:total_allocated_objects)
  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  allocations = GC.stat(:total_allocated_objects) - allocations_before
  puts format("%-28s %9.4fs  %12d objects", label, elapsed, allocations)
end

Tempfile.create(["ruby_htslib_performance", ".vcf"]) do |file|
  file.write <<~VCF
    ##fileformat=VCFv4.3
    ##contig=<ID=1,length=100>
    ##INFO=<ID=IV,Number=.,Type=Integer,Description="Integer vector">
    ##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
    ##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Depth">
    ##FORMAT=<ID=AD,Number=R,Type=Integer,Description="Allele depths">
    #CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tS1\tS2
    1\t10\t.\tA\tC\t.\tPASS\tIV=1,2,3,4\tGT:DP:AD\t0/1:10:4,6\t1/1:20:0,20
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
    measure("GT owning strings") { iterations.times { format.genotype_strings } }
    measure("GT allele iterator") do
      iterations.times do
        format.each_genotype do |_sample, genotype|
          genotype.each_allele { |_allele, _phased, _missing| }
        end
      end
    end
  end
end
