# frozen_string_literal: true

require_relative "../test_helper"

class BamAuxTest < Minitest::Test
  def setup
    @aux = nil
    @bam = HTS::Bam.open(Fixtures["poo.sort.bam"]) { |b| @aux = b.first.aux }
  end

  def teardown
    @bam.close
  end

  def test_initialize
    assert_instance_of HTS::Bam::Aux, @aux
  end

  def test_record
    assert_instance_of HTS::Bam::Record, @aux.record
  end

  def test_first
    assert_equal "70M", @aux.first
    assert_equal "70M", @aux.first
  end

  def test_to_a
    assert_equal [%w[MC 70M], ["AS", 0], ["XS", 0]], @aux.to_a
  end

  def test_each_value
    assert_equal ["70M", 0, 0], @aux.each_value.to_a
  end

  def test_to_h
    assert_equal({ "MC" => "70M", "AS" => 0, "XS" => 0 }, @aux.to_h)
  end

  def test_each_pair
    assert_equal [
      %w[MC 70M],
      ["AS", 0],
      ["XS", 0]
    ], @aux.each_pair.to_a
  end

  def test_each_tag_id
    expected = @aux.each_pair.map { |tag, value| [HTS::Bam::Aux.tag_id(tag), value] }
    assert_equal expected, @aux.each_tag_id.to_a
    assert expected.all? { |tag_id, _value| tag_id.is_a?(Integer) }
  end

  def test_each_with_type
    assert_equal [
      %w[MC Z 70M],
      ["AS", "C", 0],
      ["XS", "C", 0]
    ], @aux.each_with_type.to_a
  end

  def test_each_with_type_with_exact_types
    bam = HTS::Bam.new(Fixtures["moo.bam"])
    record = bam.first
    aux = record.aux

    aux.update_uint8("A1", 250)
    aux.update_string("ZS", "sample1")
    aux.update_char("YC", "N")
    aux.update_hex("YH", "DEADBEEF")
    aux.update_double("YD", 6.25)
    aux.update_array("ZC", [1, 2, 255], type: "C")

    typed = aux.each_with_type.each_with_object({}) do |(tag, type, value), hash|
      hash[tag] = [value, type]
    end

    assert_equal [250, "C"], typed["A1"]
    assert_equal %w[sample1 Z], typed["ZS"]
    assert_equal %w[N A], typed["YC"]
    assert_equal %w[DEADBEEF H], typed["YH"]
    assert_in_delta 6.25, typed["YD"][0], 0.0001
    assert_equal "d", typed["YD"][1]
    assert_equal [[1, 2, 255], "B:C"], typed["ZC"]
  ensure
    bam&.close
  end

  def test_get
    assert_equal "70M", @aux.get("MC")
    assert_equal 0, @aux.get("AS")
    assert_equal 0, @aux.get("XS")
  end

  def test_get_int
    assert_equal 0, @aux.get_int("AS")
    assert_equal 0, @aux.get("AS", "I")
  end

  def test_get_float
    assert_raises(TypeError) { @aux.get_float("AS") }
  end

  def test_get_string
    assert_equal "70M", @aux.get_string("MC")
  end

  def test_get_rejects_incompatible_type
    assert_raises(TypeError) { @aux.get("MC", "i") }
    assert_raises(TypeError) { @aux.get("AS", "Z") }
  end

  def test_get_square_brackets
    assert_equal "70M", @aux["MC"]
    assert_equal 0, @aux["AS"]
    assert_equal 0, @aux["XS"]
  end

  def test_get_unknown_key
    assert_nil @aux.get("UN")
    assert_nil @aux.get("UNKNOWN")
    assert_nil @aux["UN"]
  end
end
