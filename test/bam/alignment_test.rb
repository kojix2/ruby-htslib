require_relative '../test_helper'

class AlignmentTest < Minitest::Test
  def setup
    bam1 = HTS::Bam.new(File.expand_path('../assets/poo.sort.bam', __dir__))
    @aln1 = bam1.first
    bam2 = HTS::Bam.new(File.expand_path('../../htslib/test/colons.bam', __dir__))
    @aln2 = bam2.first
  end

  def test_qname
    assert_equal 'poo_3290_3833_2:0:0_2:0:0_119', @aln1.qname
    assert_equal 'chr1', @aln2.qname
  end

  def test_rnext
    assert_equal 'poo', @aln1.rnext
    assert_nil @aln2.rnext
  end

  def test_pnext
    assert_equal 3289, @aln1.pnext
    assert_nil @aln2.pnext
  end

  def test_rname
    assert_equal 'poo', @aln1.rname
    assert_equal 'chr1', @aln2.rname
  end

  def test_strand
    assert_equal '+', @aln1.strand
    assert_equal '+', @aln2.strand
  end

  def test_base_qualities
    assert_equal ([17] * 70), @aln1.base_qualities
    assert_equal ([255] * 10), @aln2.base_qualities
  end

  def test_pos
    assert_equal 3289, @aln1.pos
    assert_equal 0, @aln2.pos
  end

  def test_isize
    assert_equal 0, @aln1.isize
    assert_equal 0, @aln2.isize
  end

  def test_mapping_quality
    assert_equal 0, @aln1.mapping_quality
    assert_equal 0, @aln2.mapping_quality
  end

  def test_cigar
    assert_instance_of HTS::Bam::Cigar, @aln1.cigar
    assert_instance_of HTS::Bam::Cigar, @aln2.cigar
  end

  def test_qlen
    assert_equal 0, @aln1.qlen
    assert_equal 10, @aln2.qlen
  end

  def test_rlen
    assert_equal 0, @aln1.rlen
    assert_equal 10, @aln2.rlen
  end

  def test_seq
    assert_equal 'GGGGCAGCTTGTTCGAAGCGTGACCCCCAAGACGTCGTCCTGACGAGCACAAACTCCCATTGAGAGTGGC', @aln1.seq
    assert_equal 'AACCGCGGTT', @aln2.seq
  end

  def test_flag_str
    assert_equal 'PAIRED,UNMAP,READ2', @aln1.flag_str
    assert_equal '', @aln2.flag_str
  end

  def test_flag
    assert_equal 133, @aln1.flag
    assert_equal 0, @aln2.flag
  end
end
