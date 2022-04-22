# frozen_string_literal: true

require_relative "../test_helper"

class BcfRecordTest < Minitest::Test
  def test_bcf_path
    File.expand_path("../../htslib/test/tabix/vcf_file.bcf", __dir__)
  end

  def setup
    @bcf = HTS::Bcf.new(test_bcf_path)
    # each does not work because it reuses bcf1
    # _, @v1, @v2 = @bcf.first(3)
    @bcf.first
    @v1 = @bcf.first.clone
    @v2 = @bcf.first
  end

  def teardown
    @bcf&.close
  end

  def test_rid
    assert_equal 0, @v1.rid
    assert_equal 0, @v2.rid
  end

  def test_rid=
    assert_equal 0, @v1.rid
    @v1.rid = 1
    assert_equal 1, @v1.rid
    @v1.rid = 0
    assert_equal 0, @v1.rid
  end

  def test_chrom
    assert_equal "1", @v1.chrom
    assert_equal "1", @v2.chrom
  end

  def test_pos
    assert_equal 3_000_150, @v1.pos
    assert_equal 3_062_914, @v2.pos
  end

  def test_endpos
    assert_equal 3_000_151, @v1.endpos
    assert_equal 3_062_918, @v2.endpos
  end

  def test_id
    assert_equal ".", @v1.id
    assert_equal "id3D", @v2.id
  end

  def test_id=
    assert_equal ".", @v1.id
    @v1.id = "kirby"
    assert_equal "kirby", @v1.id
    @v1.id = "."
    assert_equal ".", @v1.id
  end

  def test_clear_id
    assert_equal ".", @v1.id
    @v1.id = "kirby"
    assert_equal "kirby", @v1.id
    @v1.clear_id
    assert_equal ".", @v1.id
  end

  def test_filter
    assert_equal "PASS", @v1.filter
    assert_equal "q10", @v2.filter
  end

  def test_qual
    assert_in_epsilon 59.2, @v1.qual
    assert_in_epsilon 12.9, @v2.qual
  end

  def test_qual=
    v = @v1.clone
    assert_in_epsilon 59.2, v.qual
    v.qual = 10.0
    assert_in_epsilon 10.0, v.qual
  end

  def test_ref
    assert_equal "C", @v1.ref
    assert_equal "GTTT", @v2.ref
  end

  def test_alt
    assert_equal ["T"], @v1.alt
    assert_equal ["G"], @v2.alt
  end

  def test_alleles
    assert_equal %w[C T], @v1.alleles
    assert_equal %w[GTTT G], @v2.alleles
  end

  def test_info
    assert_instance_of HTS::Bcf::Info, @v1.info
    assert_instance_of HTS::Bcf::Info, @v2.info
  end

  def test_format
    assert_instance_of HTS::Bcf::Format, @v1.format
    assert_instance_of HTS::Bcf::Format, @v2.format
  end
end
