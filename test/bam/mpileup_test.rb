# frozen_string_literal: true

require_relative "../test_helper"

class BamMpileupTest < Minitest::Test
  def test_multipileup_two_inputs_basic
    inputs = [Fixtures["moo.bam"], Fixtures["moo.bam"]]
    mp = HTS::Bam::Mpileup.new(inputs, overlaps: true, maxcnt: 1000)
    begin
      seen = 0
      mp.each do |columns|
        seen += 1
        assert_kind_of Array, columns
        assert_equal 2, columns.length
        # All inputs should report the same tid/pos for each column
        t = columns.map(&:tid).uniq
        p = columns.map(&:pos).uniq
        assert_equal 1, t.length
        assert_equal 1, p.length
        columns.each do |col|
          assert_kind_of HTS::Bam::Pileup::PileupColumn, col
          assert_operator col.depth, :>=, 0
        end
        break if seen >= 5
      end
      assert_operator seen, :>, 0
    ensure
      mp.close
    end
  end

  def test_multipileup_accepts_bam_instances
    b1 = HTS::Bam.open(Fixtures["moo.bam"]) # do not close here; mpileup doesn't own it
    b2 = HTS::Bam.open(Fixtures["moo.bam"]) # second handle
    mp = HTS::Bam::Mpileup.new([b1, b2])
    begin
      first = mp.each.first
      refute_nil first
      assert_equal 2, first.length
    ensure
      mp.close
      b1.close
      b2.close
    end
  end

  def test_multipileup_record_lazy_copy
    inputs = [Fixtures["moo.bam"], Fixtures["moo.bam"]]
    mp = HTS::Bam::Mpileup.new(inputs)
    begin
      kept = nil
      mp.each do |columns|
        # find first column with at least one alignment in any input
        col = columns.find { |c| !c.alignments.empty? }
        next unless col

        kept = col.alignments.first.record
        break
      end
      refute_nil kept
      # Should be usable after iteration moved on
      assert_kind_of Integer, kept.len
      assert_includes %w[= A C G T M R S V W Y H K D B N], kept.base(0)
    ensure
      mp.close
    end
  end
end
