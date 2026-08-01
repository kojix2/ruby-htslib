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

      # depth must equal the number of alignments in the column
      assert_equal got.alignments.length, got.depth

      # tid must be a valid reference id within the header target count
      assert_operator got.tid, :>=, 0
      assert_operator got.tid, :<, bam.header.target_count
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

  def test_primitive_depth_iterator
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      HTS::Bam::Pileup.open(bam) do |pileup|
        tid, pos, depth = pileup.each_depth.first
        assert_kind_of Integer, tid
        assert_kind_of Integer, pos
        assert_operator depth, :>, 0
      end
    end
  end

  def test_raw_entry_iterator
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      HTS::Bam::Pileup.open(bam) do |pileup|
        tid, pos, qpos, flag, base, quality = pileup.each_entry_raw.first
        [tid, pos, qpos, flag].each { |value| assert_kind_of Integer, value }
        assert(base.nil? || base.is_a?(Integer))
        assert(quality.nil? || quality.is_a?(Integer))
      end
    end
  end

  def test_base_count_aggregation
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      HTS::Bam::Pileup.open(bam) do |pileup|
        count_ids = []
        rows = []
        pileup.each_base_counts do |tid, pos, counts|
          assert_kind_of Integer, tid
          assert_kind_of Integer, pos
          assert_equal HTS::Bam::Pileup::BASE_COUNT_FIELDS.length, counts.length
          assert_equal counts[0], counts[1, 5].sum + counts[8]
          assert_equal counts[0], counts[6] + counts[7]
          count_ids << counts.object_id
          rows << counts.dup
          break if rows.length == 5
        end
        assert_equal 5, rows.length
        assert_equal 1, count_ids.uniq.length
      end
    end
  end

  def test_base_count_quality_filter
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      HTS::Bam::Pileup.open(bam) do |pileup|
        _tid, _pos, counts = pileup.each_base_counts(min_base_quality: 256).first
        assert_equal 0, counts[0]
      end
    end
  end

  def test_pileup_record_persists_beyond_step
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      kept = nil
      # take a record from the first non-empty column and keep it
      bam.pileup do |col|
        next if col.alignments.empty?

        kept = col.alignments.first.record
        break
      end
      refute_nil kept
      # Access after the pileup iterator has moved on; should be safe
      assert_kind_of String, kept.qname
      # Access a base in the read sequence
      assert_includes %w[= A C G T M R S V W Y H K D B N], kept.base(0)
    end
  end

  def test_cram_region_pileup
    HTS::Bam.open(Fixtures["moo.cram"]) do |bam|
      assert_equal 341, bam.pileup("chr2:350-700").first.pos
    end
  end

  # Calling record multiple times must return the same instance (idempotent lazy copy).
  def test_record_idempotent
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      r1 = r2 = nil
      bam.pileup do |col|
        next if col.alignments.empty?

        aln = col.alignments.first
        r1 = aln.record
        r2 = aln.record
        break
      end
      refute_nil r1
      assert_same r1, r2
    end
  end

  # HTSlib contract: if is_refskip is set, is_del must also be set.
  def test_refskip_implies_del
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      seen_refskip = false
      checked = 0
      bam.pileup do |col|
        col.alignments.each do |aln|
          if aln.refskip?
            seen_refskip = true
            assert aln.del?, "refskip implies del in bam_pileup1_t"
          end
        end
        checked += 1
        break if seen_refskip || checked >= 200
      end
      # If no refskip appears in the inspected window, we don't fail the test.
    end
  end
end
