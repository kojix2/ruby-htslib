#!/usr/bin/env ruby
# frozen_string_literal: true

require "htslib"

# Query an indexed BAM/CRAM file by genomic region.
# Region strings use the usual 1-based, inclusive SAMtools notation.
#
# Usage: ruby examples/bam-query.rb [input.bam] [region]

bam_path = ARGV[0] || File.expand_path("../test/fixtures/moo.bam", __dir__)
region = ARGV[1] || "chr1:1-500"

HTS::Bam.open(bam_path) do |bam|
  bam.query(region) do |record|
    puts [record.qname, record.chrom, record.pos + 1, record.mapq, record.cigar].join("\t")
  end
end
