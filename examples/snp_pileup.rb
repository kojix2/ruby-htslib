#!/usr/bin/env ruby
# frozen_string_literal: true

# A tiny, simplified snp-pileup-like tool implemented in Ruby using ruby-htslib.
# It reads a VCF/BCF and a list of BAM/CRAM files, and for each biallelic SNP
# position writes per-file ref/alt/error/deletion counts to a CSV.
#
# Usage:
#   examples/snp_pileup.rb [options] <vcf> <out.csv> <bam1> [bam2 ...]
#
# Options:
#   -q INT    Minimum mapping quality (default: 0)
#   -Q INT    Minimum base quality    (default: 0)
#   -d INT    Maximum per-file depth  (default: 4000)
#   -x        Ignore read-pair overlap adjustment (default: enabled)
#
# Notes:
# - This is intentionally simplified for clarity and as an example. It does not
#   implement all of snp-pileup's features nor advanced performance tricks.
# - When regions are used, BAM/CRAM index files are required.

require "optparse"
require "csv"
require "htslib"

# Helper class to manage streaming mpileup state per contig
class ContigPileup
  attr_reader :chrom, :mpileup, :enumerator, :current_columns, :current_pos

  def initialize(chrom, bams, opts)
    @chrom = chrom
    @mpileup = HTS::Bam::Mpileup.new(
      bams,
      region: chrom,
      maxcnt: opts[:max_depth],
      overlaps: !opts[:ignore_overlaps]
    )
    @enumerator = @mpileup.each
    advance_once
  end

  def advance_to(target_pos)
    advance_once while @current_pos && @current_pos < target_pos
  end

  def close
    @mpileup&.close
  rescue StandardError
    nil
  end

  private

  def advance_once
    @current_columns = @enumerator.next
    @current_pos = @current_columns.first&.pos
  rescue StopIteration
    @current_columns = nil
    @current_pos = nil
  end
end

# Calculate per-file ref/alt/error/deletion tallies for a pileup column
def compute_tallies(columns, ref, alt, min_mapq:, min_baseq:)
  columns.map do |col|
    r = 0
    a = 0
    e = 0
    d = 0

    col.alignments.each do |aln|
      rec_bam = aln.record
      next if rec_bam.mapq < min_mapq

      if aln.del?
        d += 1
        next
      end
      next if aln.refskip?

      qpos = aln.query_position
      bq = rec_bam.base_qual(qpos)
      next if bq < min_baseq

      base = rec_bam.base(qpos)
      case base
      when ref then r += 1
      when alt then a += 1
      else e += 1
      end
    end

    [r, a, e, d]
  end
end

# Check if a VCF record is a biallelic single-base SNP
def biallelic_snp?(record)
  alleles = record.alleles
  alleles.length == 2 && alleles[0].length == 1 && alleles[1].length == 1
end

opts = {
  min_mapq: 0,
  min_baseq: 0,
  max_depth: 4000,
  ignore_overlaps: false
}

op = OptionParser.new do |o|
  o.banner = "Usage: #{$PROGRAM_NAME} [options] <vcf> <out.csv> <bam1> [bam2 ...]"
  o.on("-q INT", Integer, "Minimum mapping quality (default: #{opts[:min_mapq]})") { |v| opts[:min_mapq] = v }
  o.on("-Q INT", Integer, "Minimum base quality (default: #{opts[:min_baseq]})") { |v| opts[:min_baseq] = v }
  o.on("-d INT", Integer, "Maximum per-file depth (default: #{opts[:max_depth]})") { |v| opts[:max_depth] = v }
  o.on("-x", "Disable overlap detection (default: enabled)") { opts[:ignore_overlaps] = true }
  o.on("-h", "Show help") do
    puts o
    exit 0
  end
end

begin
  op.order!
rescue OptionParser::ParseError => e
  warn e.message
  warn op
  exit 1
end

if ARGV.length < 3
  warn op
  exit 1
end

vcf_path = ARGV.shift
out_path = ARGV.shift
bam_paths = ARGV

# Open BAM/CRAM inputs
bams = bam_paths.map { |p| HTS::Bam.open(p) }

begin
  # Prepare CSV
  CSV.open(out_path, "w") do |csv|
    # Header
    header = %w[Chromosome Position Ref Alt]
    bams.each_with_index do |_b, i|
      idx = i + 1
      header += ["File#{idx}R", "File#{idx}A", "File#{idx}E", "File#{idx}D"]
    end
    csv << header

    # Build a chrom->tid map from the first BAM header for quick checks
    bam0_hdr = bams.first.header

    # Iterate VCF/BCF and stream a single Mpileup per contig
    HTS::Bcf.open(vcf_path) do |bcf|
      contig_pileup = nil

      begin
        bcf.each do |rec|
          next unless biallelic_snp?(rec)

          chrom = rec.chrom
          pos0  = rec.pos # 0-based
          ref   = rec.alleles[0]
          alt   = rec.alleles[1]

          # Switch contig => reinitialize mpileup state
          if !contig_pileup || contig_pileup.chrom != chrom
            contig_pileup&.close
            tid = bam0_hdr.get_tid(chrom)
            if tid < 0
              contig_pileup = nil
              next
            end
            contig_pileup = ContigPileup.new(chrom, bams, opts)
          end

          next unless contig_pileup

          # Advance mpileup to this SNP position
          contig_pileup.advance_to(pos0)

          # Compute tallies if coverage exactly at this position
          next unless contig_pileup.current_pos == pos0

          tallies = compute_tallies(
            contig_pileup.current_columns,
            ref,
            alt,
            min_mapq: opts[:min_mapq],
            min_baseq: opts[:min_baseq]
          )

          # Emit CSV row only if some counts exist
          next unless tallies.any? { |raed| raed.any?(&:positive?) }

          row = [chrom, pos0 + 1, ref, alt]
          tallies.each { |raed| row.concat(raed) }
          csv << row
        end
      ensure
        contig_pileup&.close
      end
    end
  end
ensure
  bams.each do |b|
    b.close
  rescue StandardError
    nil
  end
end

warn "Done: wrote #{out_path}"
