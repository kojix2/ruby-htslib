# frozen_string_literal: true

require_relative "../test_helper"

class HeaderTest < Minitest::Test
  def setup
    @bam = HTS::Bam.new(Fixtures["poo.sort.bam"])
    @bam_header = @bam.header
  end

  def test_initialize
    assert_instance_of HTS::Bam::Header, @bam_header
  end

  def test_seqs
    assert_equal ["poo"], @bam_header.seqs
  end

  def test_text
    header_text = <<~TEXT
      @HD	VN:1.3	SO:coordinate
      @SQ	SN:poo	LN:5000
      @PG	ID:bwa	PN:bwa	VN:0.7.17-r1188	CL:bwa mem poo.fa poos_1.fq poos_2.fq
      @PG	ID:samtools	PN:samtools	PP:bwa	VN:1.10-96-gcc4e1a6	CL:samtools sort -o poo.sort.bam b.bam
    TEXT
    assert_equal header_text, @bam_header.text
  end
end
