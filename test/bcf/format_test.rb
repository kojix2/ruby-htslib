# frozen_string_literal: true

require_relative "../test_helper"

class BcfFormatTest < Minitest::Test
  def test_bcf_path
    File.expand_path("../../htslib/test/tabix/vcf_file.bcf", __dir__)
  end

  def setup
    @bcf = HTS::Bcf.new(test_bcf_path)
    rec2 = @bcf.take(3).last
    @fmt = rec2.format
  end

  def teardown
    @bcf&.close
  end

  def test_get_with_type
    assert_equal [409, 409], @fmt.get("GQ", :int)
    assert_equal [35, 35], @fmt.get("DP", :int)
    assert_equal [-20.0, -5.0, -20.0, -20.0, -5.0, -20.0], @fmt.get("GL", :float)
  end

  def test_get_like_crystal
    assert_equal [409, 409], @fmt.get_int("GQ")
    assert_equal [35, 35], @fmt.get_int("DP")
    assert_equal [-20.0, -5.0, -20.0, -20.0, -5.0, -20.0], @fmt.get_float("GL")
  end
end
