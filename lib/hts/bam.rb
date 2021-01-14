# frozen_string_literal: true

# Create a skeleton using hts-python as a reference.
# https://github.com/quinlan-lab/hts-python

module HTS
  class BamHeader
    def initialize; end

    def seqs; end
  end

  class Cigar
    def initialize; end

    def to_s; end

    def inspect; end
  end

  class Alignment
    def initialize; end

    def self.rom_sam_str; end

    def tags; end

    def qname; end

    def qname=; end

    def rnext; end

    def pnext; end

    def rname; end

    def strand; end

    def base_qualities; end

    def pos; end

    def pos=; end

    def isize; end

    def mapping_quality; end

    def cigar; end

    def qlen; end

    def rlen; end

    def seqs; end

    def flag_str; end

    def flag; end

    # def eql?
    # def hash

    def inspect; end

    def to_s; end
  end

  class Bam
    def initialize; end

    def self.header_from_fasta; end

    def inspect; end

    def write; end

    def close; end

    def flush; end

    def to_s; end

    def each; end

    # def call
  end
end
