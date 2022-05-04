# frozen_string_literal: true

require "htslib"

bcf_path = File.expand_path("../htslib/test/tabix/vcf_file.bcf", __dir__)

HTS::Bcf.open(bcf_path) do |bcf|
  bcf.each do |r|
    pp  chrom: r.chrom,
        pos: r.pos,
        id: r.id,
        qual: r.qual.round(2),
        ref: r.ref,
        alt: r.alt,
        filter: r.filter,
        info: r.info.to_h,
  end
end
