# frozen_string_literal: true

require "hts/version"
require "hts/native"

module HTS
  class Error < StandardError; end

  autoload :Hts,   "hts/hts"
  autoload :Bam,   "hts/bam"
  autoload :Bcf,   "hts/bcf"
  autoload :Faidx, "hts/faidx"
  autoload :Tabix, "hts/tabix"
end
