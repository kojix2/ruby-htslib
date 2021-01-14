# frozen_string_literal: true

# Create a skeleton using hts-python as a reference.
# https://github.com/quinlan-lab/hts-python

module HTS
  class VCF
    def initialize; end

    def inspect; end

    def each; end

    def seq; end

    def n_samples; end
  end

  class Variant
    def initialize; end

    def inspect; end

    def formats; end

    def genotypes; end
  end

  class Format
    def initialize; end
  end
end
