# frozen_string_literal: true

require_relative "../test_helper"

class BamCigarTest < Minitest::Test
  def setup
    @bam1 = HTS::Bam.new(Fixtures["poo.sort.bam"])
    @cgr1 = @bam1.first.cigar
    @bam2 = HTS::Bam.new(File.expand_path("../../htslib/test/colons.bam", __dir__))
    @cgr2 = @bam2.first.cigar
    @cgr3 = HTS::Bam::Cigar.parse("1M1I1M1D1M1S1H")
  end

  def teardown
    @bam1.close
    @bam2.close
  end

  def test_initialize
    assert_instance_of HTS::Bam::Cigar, @cgr1
    assert_instance_of HTS::Bam::Cigar, @cgr2
  end

  def test_parse
    3.times do
      c_str = "MIDNSHP=X".chars.shuffle.map { |op| "#{rand(1..20)}#{op}" }.join
      assert_equal c_str, HTS::Bam::Cigar.parse(c_str).to_s
    end
  end

  def test_qlen
    assert_equal 0, @cgr1.qlen
    assert_equal 10, @cgr2.qlen
    assert_equal 5, @cgr3.qlen
  end

  def test_rlen
    assert_equal 0, @cgr1.rlen
    assert_equal 10, @cgr2.rlen
    assert_equal 4, @cgr3.rlen
  end

  def test_to_s
    assert_equal "", @cgr1.to_s
    assert_equal "10M", @cgr2.to_s
    assert_equal "1M1I1M1D1M1S1H", @cgr3.to_s
  end

  def test_to_a
    assert_equal [], @cgr1.to_a
    assert_equal [["M", 10]], @cgr2.to_a
    assert_equal [["M", 1], ["I", 1], ["M", 1], ["D", 1], ["M", 1], ["S", 1], ["H", 1]], @cgr3.to_a
  end

  def test_equal_operator
    other = HTS::Bam::Cigar.parse("1M1I1M1D1M1S1H")
    other2 = HTS::Bam::Cigar.parse("1M1I1M1D1M1S")
    assert_equal true, @cgr3 == other
    assert_equal false, @cgr3 == other2
  end
end
