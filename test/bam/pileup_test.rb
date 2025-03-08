# frozen_string_literal: true

require_relative "../test_helper"

class PileupTest < Minitest::Test
  def setup
    @bam = HTS::Bam.new(Fixtures["moo.bam"])
  end

  def teardown
    @bam.close if @bam && !@bam.closed?
  end

  def test_pileup_initialization
    pileup = @bam.pileup
    assert_instance_of HTS::Bam::Pileup, pileup
  end

  def test_pileup_each_with_block
    pileup = @bam.pileup
    entries_count = 0

    pileup.each do |entry|
      #assert_instance_of HTS::Bam::PileupEntry, entry
      entries_count += 1
    end

    assert entries_count > 0, "No pileup entries were processed"
  end

  def test_pileup_each_without_block
    pileup = @bam.pileup
    enum = pileup.each
    assert_instance_of Enumerator, enum
  end

  def test_pileup_entry_methods
    pileup = @bam.pileup

    entry = pileup.each.first

    assert_kind_of Integer, entry.qpos
    assert_kind_of Integer, entry.indel
    assert_kind_of Integer, entry.level

    assert_includes [true, false], entry.is_del?
    assert_includes [true, false], entry.is_refskip?

    #assert_kind_of String, entry.base
    #assert_match(/[ACGTN]/, entry.base) unless entry.is_del?
  end

  def test_pileup_entry_to_s
    pileup = @bam.pileup
    entry = pileup.each.first

    assert_kind_of String, entry.to_s

    assert_match(/Position:/, entry.to_s)
    assert_match(/Indel:/, entry.to_s)
    assert_match(/Level:/, entry.to_s)
    assert_match(/Base:/, entry.to_s)
    assert_match(/Is_del:/, entry.to_s)
    assert_match(/Is_refskip:/, entry.to_s)
  end

  # def test_pileup_initialization_error
  #   HTS::LibHTS.stub :bam_plp_init, FFI::Pointer::NULL do
  #     assert_raises(RuntimeError, "Failed to initialize pileup") do
  #       @bam.pileup
  #     end
  #   end
  # end

  # def test_pileup_push_error
  #   pileup = @bam.pileup

  #   HTS::LibHTS.stub :bam_plp_push, -1 do
  #     assert_raises(RuntimeError, "Failed to push BAM record") do
  #       pileup.each.first
  #     end
  #   end
  # end
end
