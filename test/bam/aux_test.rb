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

  def test_get
    assert_equal "70M", @aux.get("MC")
    assert_equal 0, @aux.get("AS")
    assert_equal 0, @aux.get("XS")
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
