# frozen_string_literal: true

require_relative "../test_helper"

class BamPileupTest < Minitest::Test
  def test_pileup_yields_columns
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      got = nil
      bam.pileup do |col|
        got = col
        break
      end
      refute_nil got
      assert_kind_of HTS::Bam::Pileup::PileupColumn, got
      assert_kind_of Integer, got.tid
      assert_kind_of Integer, got.pos
      assert_kind_of Array, got.alignments
      assert_kind_of Integer, got.depth
      assert_operator got.depth, :>=, 0
    end
  end

  def test_pileup_basic_each
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      count = 0
      bam.pileup do |col|
        count += 1
        assert_kind_of Integer, col.tid
        assert_kind_of Integer, col.pos
        assert_operator col.depth, :>=, 0
        col.alignments.each do |aln|
          qpos = aln.query_position
          # base access through lightweight view
          base = aln.record.base(qpos)
          assert_kind_of String, base
        end
        break if count >= 5
      end
      assert_operator count, :>, 0
    end
  end
end
