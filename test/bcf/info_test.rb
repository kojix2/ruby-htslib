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

  def test_get_like_crystal
    assert_equal [1, 2, 3, 4], @info.get_int("DP4")
    assert_equal [4], @info.get_int("AN")
    assert_equal [2], @info.get_int("AC")
    assert_equal true, @info.get_flag("INDEL")
    assert_equal "test", @info.get_string("STR")
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
    assert_nil @info.get_int("UNKNOWN")
    assert_nil @info.get("UNKNOWN", :float)
    assert_nil @info.get_float("UNKNOWN")
    assert_nil @info.get("UNKNOWN", :flag)
    assert_nil @info.get_flag("UNKNOWN")
    assert_nil @info.get("UNKNOWN", :str)
    assert_nil @info.get_string("UNKNOWN")
  end

  def test_fields
    assert_equal [{ name: "DP4", n: 4, type: :int, key: 3 },
                  { name: "AN", n: 1, type: :int, key: 11 },
                  { name: "AC", n: 1_048_575, type: :int, key: 10 },
                  { name: "INDEL", n: 0, type: :flag, key: 12 },
                  { name: "STR", n: 1, type: :string, key: 13 }], @info.fields
  end

  def test_to_h
    assert_equal(
      { "DP4" => [1, 2, 3, 4], "AN" => [4], "AC" => [2], "INDEL" => true, "STR" => "test" },
      @info.to_h
    )
  end
end
