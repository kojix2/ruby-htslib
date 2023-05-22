# frozen_string_literal: true

require_relative "../test_helper"

class BamHeaderTest < Minitest::Test
  def setup
    @bam = HTS::Bam.new(Fixtures["poo.sort.bam"])
    @bam_header = @bam.header
  end

  def teardown
    @bam.close
  end

  def test_initialize
    assert_instance_of HTS::Bam::Header, @bam_header
  end

  def test_initialize_with_block
    assert_instance_of HTS::Bam::Header, HTS::Bam::Header.new do |h|
      assert_instance_of HTS::Bam::Header, h
    end
  end

  def test_target_count
    assert_equal 1, @bam_header.target_count
  end

  def test_target_names
    assert_equal ["poo"], @bam_header.target_names
  end

  def test_target_len
    assert_equal [5000], @bam_header.target_len
  end

  def test_name2tid
    assert_equal 0, @bam_header.name2tid("poo")
  end

  def test_tid2name
    assert_equal "poo", @bam_header.tid2name(0)
  end

  def test_to_s
    header_text = <<~TEXT
      @HD	VN:1.3	SO:coordinate
      @SQ	SN:poo	LN:5000
      @PG	ID:bwa	PN:bwa	VN:0.7.17-r1188	CL:bwa mem poo.fa poos_1.fq poos_2.fq
      @PG	ID:samtools	PN:samtools	PP:bwa	VN:1.10-96-gcc4e1a6	CL:samtools sort -o poo.sort.bam b.bam
    TEXT
    assert_equal header_text, @bam_header.to_s
  end
end
