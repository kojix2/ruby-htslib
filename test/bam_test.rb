# frozen_string_literal: true

require_relative "test_helper"

class BamTest < Minitest::Test
  def test_bam_path
    Fixtures["poo.sort.bam"]
  end

  def setup
    @bam = HTS::Bam.new(test_bam_path)
  end

  def teardown
    @bam&.close
  end

  def test_initialize_sam
    skip
    sam = HTS::Bam.new Fixture["poo.sort.sam"]
    assert_instance_of HTS::Bam, sam
  end

  def test_initialize_bam
    assert_instance_of HTS::Bam, @bam
  end

  def test_initialize_no_file
    assert_raises(StandardError) { HTS::Bam.new("no_file") }
  end

  def test_file_path
    assert_equal test_bam_path, @bam.file_path
  end

  def test_mode
    assert_equal "r", @bam.mode
  end

  def test_header
    assert_instance_of HTS::Bam::Header, @bam.header
  end

  # def test_close
  #   assert 0, @bam.close
  # end

  def test_each
    alns = @bam.to_a
    assert_equal true, (alns.all? { |i| i.is_a?(HTS::Bam::Record) })
  end

  def test_puery
    # FIXME:
    arr = []
    @bam.query("poo:3200-3300") do |aln|
      arr << aln.start
    end
    assert_equal [3289, 3292, 3293, 3298], arr
  end
end
