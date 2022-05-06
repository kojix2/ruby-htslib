# frozen_string_literal: true

require_relative "../test_helper"

class BamCigarTest < Minitest::Test
  def setup
    @bam1 = HTS::Bam.new(Fixtures["poo.sort.bam"])
    @cgr1 = @bam1.first.cigar
    @bam2 = HTS::Bam.new(File.expand_path("../../htslib/test/colons.bam", __dir__))
    @cgr2 = @bam2.first.cigar
  end

  def teardown
    @bam1.close
    @bam2.close
  end

  def test_initialize
    assert_instance_of HTS::Bam::Cigar, @cgr1
    assert_instance_of HTS::Bam::Cigar, @cgr2
  end

  def test_to_s
    assert_equal "", @cgr1.to_s
    assert_equal "10M", @cgr2.to_s
  end

  def test_to_a
    assert_equal [], @cgr1.to_a
    assert_equal [["M", 10]], @cgr2.to_a
  end
end
