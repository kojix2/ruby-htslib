# frozen_string_literal: true

require_relative "../test_helper"

class BaseModTest < Minitest::Test
  # NOTE: This test requires BAM files with MM/ML tags for base modifications
  # For now, we'll create basic structural tests that don't require actual data

  def setup
    # We'll need a BAM file with base modification tags for full testing
    # For now, test the class structure
  end

  def test_modification_class_exists
    assert defined?(HTS::Bam::BaseMod::Modification)
  end

  def test_modification_initialization
    mod = HTS::Bam::BaseMod::Modification.new(
      modified_base: 109, # 'm'
      canonical_base: 67, # 'C'
      strand: 0,
      qual: 204 # 256 * 0.8
    )

    assert_equal 109, mod.modified_base
    assert_equal 67, mod.canonical_base
    assert_equal 0, mod.strand
    assert_equal 204, mod.qual
  end

  def test_modification_probability
    mod = HTS::Bam::BaseMod::Modification.new(
      modified_base: 109, # 'm'
      canonical_base: 67, # 'C'
      strand: 0,
      qual: 256 # 256 * 1.0
    )

    assert_in_delta 1.0, mod.probability, 0.01
  end

  def test_modification_probability_nil
    mod = HTS::Bam::BaseMod::Modification.new(
      modified_base: 109, # 'm'
      canonical_base: 67, # 'C'
      strand: 0,
      qual: -1 # unknown
    )

    assert_nil mod.probability
  end

  def test_modification_to_h
    mod = HTS::Bam::BaseMod::Modification.new(
      modified_base: 109, # 'm'
      canonical_base: 67, # 'C'
      strand: 0,
      qual: 204
    )

    hash = mod.to_h
    assert_equal 109, hash[:modified_base]
    assert_equal "m", hash[:code]
    assert_equal 67, hash[:canonical_base]
    assert_equal "C", hash[:canonical]
    assert_equal 0, hash[:strand]
    assert_equal 204, hash[:qual]
  end

  def test_modification_to_s
    mod = HTS::Bam::BaseMod::Modification.new(
      modified_base: 109, # 'm'
      canonical_base: 67, # 'C'
      strand: 0,
      qual: 204
    )

    assert_match(/C->m/, mod.to_s)
    assert_match(/0\.\d+/, mod.to_s) # Should contain probability
  end

  def test_modification_to_s_without_likelihood
    mod = HTS::Bam::BaseMod::Modification.new(
      modified_base: 109, # 'm'
      canonical_base: 67, # 'C'
      strand: 0,
      qual: -1
    )

    assert_equal "C->m", mod.to_s
  end

  def test_position_class_exists
    assert defined?(HTS::Bam::BaseMod::Position)
  end

  def test_position_initialization
    mods = [
      HTS::Bam::BaseMod::Modification.new(
        modified_base: 109, # 'm'
        canonical_base: 67, # 'C'
        strand: 0,
        qual: 204
      )
    ]
    pos = HTS::Bam::BaseMod::Position.new(10, mods)

    assert_equal 10, pos.position
    assert_equal 1, pos.modifications.length
  end

  def test_position_methylated?
    mods = [
      HTS::Bam::BaseMod::Modification.new(
        modified_base: 109, # 'm'
        canonical_base: 67, # 'C'
        strand: 0,
        qual: 204
      )
    ]
    pos = HTS::Bam::BaseMod::Position.new(10, mods)

    assert pos.methylated?
  end

  def test_position_not_methylated?
    mods = [
      HTS::Bam::BaseMod::Modification.new(
        modified_base: 104, # 'h'
        canonical_base: 67, # 'C'
        strand: 0,
        qual: 204
      )
    ]
    pos = HTS::Bam::BaseMod::Position.new(10, mods)

    refute pos.methylated?
  end

  def test_position_hydroxymethylated?
    mods = [
      HTS::Bam::BaseMod::Modification.new(
        modified_base: 104, # 'h'
        canonical_base: 67, # 'C'
        strand: 0,
        qual: 204
      )
    ]
    pos = HTS::Bam::BaseMod::Position.new(10, mods)

    assert pos.hydroxymethylated?
  end

  def test_position_to_h
    mods = [
      HTS::Bam::BaseMod::Modification.new(
        modified_base: 109, # 'm'
        canonical_base: 67, # 'C'
        strand: 0,
        qual: 204
      )
    ]
    pos = HTS::Bam::BaseMod::Position.new(10, mods)

    hash = pos.to_h
    assert_equal 10, hash[:position]
    assert_equal 1, hash[:modifications].length
  end

  def test_position_to_s
    mods = [
      HTS::Bam::BaseMod::Modification.new(
        modified_base: 109, # 'm'
        canonical_base: 67, # 'C'
        strand: 0,
        qual: 204
      )
    ]
    pos = HTS::Bam::BaseMod::Position.new(10, mods)

    str = pos.to_s
    assert_match(/pos=10/, str)
  end

  def test_basemod_class_exists
    assert defined?(HTS::Bam::BaseMod)
  end

  # Test with actual BAM file (if available with MM/ML tags)
  # This test will be skipped if no suitable test data is available
  def test_basemod_with_bam_record
    # Skip this test if we don't have appropriate test data
    skip "No BAM file with base modification tags available for testing"

    # Example of how this would work with real data:
    # bam = HTS::Bam.new("test_file_with_mods.bam")
    # record = bam.first
    # base_mod = record.base_mod
    #
    # base_mod.parse
    # assert base_mod.modification_types.length > 0
    #
    # base_mod.each_position do |pos|
    #   assert pos.position >= 0
    #   assert pos.modifications.length > 0
    # end
  end

  def test_record_has_base_mod_method
    # Test that Record class has base_mod method
    # We need a minimal BAM file for this
    bam_path = File.expand_path("../test/moo.bam", __dir__)

    if File.exist?(bam_path)
      bam = HTS::Bam.new(bam_path)
      record = bam.first

      assert_respond_to record, :base_mod

      base_mod = record.base_mod
      assert_instance_of HTS::Bam::BaseMod, base_mod

      bam.close
    else
      skip "Test BAM file not found"
    end
  end

  def test_basemod_enumerable
    # Test that BaseMod includes Enumerable
    assert HTS::Bam::BaseMod.included_modules.include?(Enumerable)
  end

  def test_modification_inspect
    mod = HTS::Bam::BaseMod::Modification.new(
      modified_base: 109, # 'm'
      canonical_base: 67, # 'C'
      strand: 0,
      qual: 204
    )

    inspect_str = mod.inspect
    assert_match(/HTS::Bam::BaseMod::Modification/, inspect_str)
    assert_match(/C->m/, inspect_str)
  end

  def test_position_inspect
    mods = [
      HTS::Bam::BaseMod::Modification.new(
        modified_base: 109, # 'm'
        canonical_base: 67, # 'C'
        strand: 0,
        qual: 204
      )
    ]
    pos = HTS::Bam::BaseMod::Position.new(10, mods)

    inspect_str = pos.inspect
    assert_match(/HTS::Bam::BaseMod::Position/, inspect_str)
    assert_match(/pos=10/, inspect_str)
  end
end
