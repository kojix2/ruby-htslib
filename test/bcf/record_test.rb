# frozen_string_literal: true

require_relative "../test_helper"

class BcfRecordTest < Minitest::Test
  def test_bcf_path
    File.expand_path("../../htslib/test/tabix/vcf_file.bcf", __dir__)
  end

  def setup
    @bcf = HTS::Bcf.new(test_bcf_path)
    _, @v1, @v2 = @bcf.first(3)
  end

  def test_chrom
    assert_equal "1", @v1.chrom
    assert_equal "1", @v2.chrom
  end

  def test_pos
    assert_equal 3_000_151, @v1.pos
    assert_equal 3_062_915, @v2.pos
  end

  def test_start
    assert_equal 3_000_150, @v1.start
    assert_equal 3_062_914, @v2.start
  end

  def test_stop
    assert_equal 3_000_151, @v1.stop
    assert_equal 3_062_918, @v2.stop
  end

  def test_id
    assert_equal ".", @v1.id
    assert_equal "id3D", @v2.id
  end

  def test_filter
    assert_equal "PASS", @v1.filter
    assert_equal "q10", @v2.filter
  end

  def test_qual
    assert_in_epsilon 59.2, @v1.qual
    assert_in_epsilon 12.9, @v2.qual
  end

  def test_ref
    assert_equal "C", @v1.ref
    assert_equal "GTTT", @v2.ref
  end

  def test_alt
    assert_equal ["T"], @v1.alt
    assert_equal ["G"], @v2.alt
  end

  end
end
