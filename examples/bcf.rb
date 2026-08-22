# frozen_string_literal: true

require "htslib"

bcf_path = ARGV[0] || File.expand_path("../test/fixtures/test.bcf", __dir__)

HTS::Bcf.open(bcf_path) do |bcf|
  bcf.each do |r|
    pp  chrom: r.chrom,
        pos: r.pos + 1,
        id: r.id,
        qual: r.qual.round(2),
        ref: r.ref,
        alt: r.alt,
        filters: r.filter,
        info: r.info.to_h,
        format: r.format.to_h
  end
end
