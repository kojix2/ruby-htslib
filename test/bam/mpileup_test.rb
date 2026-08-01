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

  def test_multipileup_region_accepts_cram
    mp = HTS::Bam::Mpileup.new([Fixtures["moo.cram"]], region: "chr2:350-700")
    begin
      assert_equal 341, mp.first.first.pos
    ensure
      mp.close
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

  def test_each_depth_uses_reusable_view
    mp = HTS::Bam::Mpileup.new([Fixtures["moo.bam"], Fixtures["moo.bam"]])
    begin
      view_ids = []
      rows = []
      mp.each_depth do |tid, pos, depths|
        assert_kind_of Integer, tid
        assert_kind_of Integer, pos
        assert_instance_of HTS::Bam::Mpileup::DepthView, depths
        assert_equal 2, depths.length
        assert_equal depths[0], depths[-2]
        view_ids << depths.object_id
        rows << depths.to_a
        break if rows.length == 5
      end
      assert_equal 5, rows.length
      assert_equal 1, view_ids.uniq.length
      rows.each { |depths| assert_equal depths.first, depths.last }
    ensure
      mp.close
    end
  end

  def test_each_entry_raw_yields_primitives
    mp = HTS::Bam::Mpileup.new([Fixtures["moo.bam"], Fixtures["moo.bam"]])
    begin
      row = mp.each_entry_raw.first
      refute_nil row
      assert_equal 7, row.length
      input_index, tid, pos, qpos, flag, base, quality = row
      [input_index, tid, pos, qpos, flag].each { |value| assert_kind_of Integer, value }
      assert_includes [0, 1], input_index
      assert base.nil? || base.is_a?(Integer)
      assert quality.nil? || quality.is_a?(Integer)
    ensure
      mp.close
    end
  end

  def test_each_column_raw_exposes_borrowed_buffers
    mp = HTS::Bam::Mpileup.new([Fixtures["moo.bam"], Fixtures["moo.bam"]])
    begin
      tid, pos, counts, pileups, input_count = mp.each_column_raw.first
      assert_kind_of Integer, tid
      assert_kind_of Integer, pos
      assert_equal 2, input_count
      assert_kind_of FFI::Pointer, counts
      assert_kind_of FFI::Pointer, pileups
      assert_equal counts.get_int32(0), counts.get_int32(FFI.type_size(:int))
    ensure
      mp.close
    end
  end

  def test_each_base_counts_aggregates_each_input
    mp = HTS::Bam::Mpileup.new([Fixtures["moo.bam"], Fixtures["moo.bam"]])
    begin
      outer_ids = []
      inner_ids = []
      rows = []
      mp.each_base_counts do |_tid, _pos, counts_by_input|
        assert_equal 2, counts_by_input.length
        assert_equal counts_by_input[0], counts_by_input[1]
        counts_by_input.each do |counts|
          assert_equal counts[0], counts[1, 5].sum + counts[8]
          assert_equal counts[0], counts[6] + counts[7]
        end
        outer_ids << counts_by_input.object_id
        inner_ids << counts_by_input.map(&:object_id)
        rows << counts_by_input.map(&:dup)
        break if rows.length == 5
      end
      assert_equal 5, rows.length
      assert_equal 1, outer_ids.uniq.length
      assert_equal 1, inner_ids.transpose[0].uniq.length
      assert_equal 1, inner_ids.transpose[1].uniq.length
    ensure
      mp.close
    end
  end
end
