# frozen_string_literal: true

require_relative "../test_helper"

class BcfInfoTest < Minitest::Test
  def test_bcf_path
    File.expand_path("../../htslib/test/tabix/vcf_file.bcf", __dir__)
  end

  def setup
    @bcf = HTS::Bcf.new(test_bcf_path)
    rec2 = @bcf.take(3).last
    @info = rec2.info
  end

  def teardown
    @bcf&.close
  end

  def test_get_with_type
    assert_equal [1, 2, 3, 4], @info.get("DP4", :int)
    assert_equal [4], @info.get("AN", :int)
    assert_equal [2], @info.get("AC", :int)
    assert_equal true, @info.get("INDEL", :flag)
    assert_equal "test", @info.get("STR", :string)
  end

  def test_get_without_type
    assert_equal [1, 2, 3, 4], @info.get("DP4")
    assert_equal [4], @info.get("AN")
    assert_equal [2], @info.get("AC")
    assert_equal true, @info.get("INDEL")
    assert_equal "test", @info.get("STR")
  end

  def test_get_unknown_key
    assert_nil @info.get("UNKNOWN")
    assert_nil @info.get("UNKNOWN", :int)
    assert_nil @info.get("UNKNOWN", :float)
    assert_nil @info.get("UNKNOWN", :flag)
    assert_nil @info.get("UNKNOWN", :str)
  end

  def test_fields
    assert_equal [
      { name: "DP4", n: 4, vtype: 1, i: 3 },
      { name: "AN", n: 1, vtype: 1, i: 11 },
      { name: "AC", n: 1_048_575, vtype: 1, i: 10 },
      { name: "INDEL", n: 0, vtype: 0, i: 12 },
      { name: "STR", n: 1, vtype: 7, i: 13 }
    ], @info.fields
  end
end
