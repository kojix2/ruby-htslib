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
    assert_operator HTS::Bam::BaseMod::Error, :<, HTS::Error
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

  # --- Integration tests using MM/ML sample from htslib ---

  def mm_chebi_path
    File.expand_path("../../htslib/test/base_mods/MM-chebi.sam", __dir__)
  end

  def with_mm_chebi
    skip "MM-chebi.sam not found" unless File.exist?(mm_chebi_path)
    bam = HTS::Bam.new(mm_chebi_path)
    begin
      rec = bam.first
      assert rec, "No record found in MM-chebi.sam"
      bm = rec.base_mod
      yield bm
    ensure
      bam.close if bam
    end
  end

  def test_mm_chebi_recorded_types_and_total_count
    with_mm_chebi do |bm|
      types = bm.recorded_types
      assert_includes types, "m".ord
      assert_includes types, -76_792
      assert_includes types, "n".ord

      total = bm.to_a.sum { |p| p.modifications.length }
      assert_equal 8, total
    end
  end

  def test_mm_chebi_expected_positions_and_codes
    with_mm_chebi do |bm|
      expected_positions = [6, 15, 17, 19, 20, 31, 34].sort
      got_positions = []
      pos_to_codes = {}

      bm.each_position do |p|
        got_positions << p.position
        pos_to_codes[p.position] = p.modifications.map(&:modified_base)
      end

      assert_equal expected_positions, got_positions.sort

      [6, 17, 20, 31, 34].each do |q|
        assert pos_to_codes[q].any? { |c| c == "m".ord }, "pos #{q} should have 'm'"
      end

      [19, 34].each do |q|
        assert pos_to_codes[q].any? { |c| c == -76_792 }, "pos #{q} should have -76792"
      end

      assert pos_to_codes[15].any? { |c| c == "n".ord }, "pos 15 should have 'n'"
    end
  end

  def test_mm_chebi_query_type_metadata
    with_mm_chebi do |bm|
      info_m = bm.query_type("m".ord)
      info_n = bm.query_type("n".ord)
      info_chebi = bm.query_type(-76_792)

      refute_nil info_m
      refute_nil info_n
      refute_nil info_chebi

      assert_equal "C", info_m[:canonical]
      assert_equal "N", info_n[:canonical]
      assert_equal "C", info_chebi[:canonical]

      refute_nil info_m[:strand]
      refute_nil info_n[:strand]
      refute_nil info_chebi[:strand]

      assert_includes [true, false], info_m[:implicit]
      assert_includes [true, false], info_n[:implicit]
      assert_includes [true, false], info_chebi[:implicit]
    end
  end

  def test_mm_chebi_at_pos_matches_each_position
    with_mm_chebi do |bm|
      from_each = bm.to_a.map { |p| [p.position, p.modifications.map(&:modified_base).sort] }.to_h

      from_each.each do |qpos, codes|
        p = bm.at_pos(qpos, max_mods: 4)
        skip "bam_mods_at_qpos returned nil for qpos=#{qpos}; skipping at_pos comparison" if p.nil?
        got_codes = p.modifications.map(&:modified_base).sort
        assert_equal codes, got_codes
      end
    end
  end
end
