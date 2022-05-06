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
    @bcf.close
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

  def test_get_without_type
    assert_equal [409, 409], @fmt.get("GQ")
    assert_equal [35, 35], @fmt.get("DP")
    assert_equal [-20.0, -5.0, -20.0, -20.0, -5.0, -20.0], @fmt.get("GL")
  end

  def test_fields
    assert_equal [{ name: "GT", n: 1, type: :string, id: 4 },
                  { name: "GQ", n: 1, type: :int, id: 5 },
                  { name: "DP", n: 1, type: :int, id: 6 },
                  { name: "GL", n: 1_048_575, type: :float, id: 7 }],
                 @fmt.fields
  end

  def test_to_h
    assert_equal(
      # FIXME: Maybe GT should be string?
      { "GT" => [2, 4, 2, 4], "GQ" => [409, 409], "DP" => [35, 35],
        "GL" => [-20.0, -5.0, -20.0, -20.0, -5.0, -20.0] },
      @fmt.to_h
    )
  end
end
