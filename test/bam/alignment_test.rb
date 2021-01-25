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

  def test_mate_chrom
    assert_equal 'poo', @aln1.mate_chrom
    assert_equal '', @aln2.mate_chrom
  end

  def test_mate_tid
    assert_equal 0, @aln1.mate_tid
    assert_equal(-1, @aln2.mate_tid)
  end

  def test_tid
    assert_equal 0, @aln1.tid
    assert_equal 0, @aln2.tid
  end

  def test_mate_pos
    assert_equal 3289, @aln1.mate_pos
    assert_equal(-1, @aln2.mate_pos)
  end

  def test_chrom
    assert_equal 'poo', @aln1.chrom
    assert_equal 'chr1', @aln2.chrom
  end

  def test_strand
    assert_equal '+', @aln1.strand
    assert_equal '+', @aln2.strand
  end

  def test_start
    assert_equal 3289, @aln1.start
    assert_equal 0, @aln2.start
  end

  def test_stop
    assert_equal 3290, @aln1.stop # may be strange?
    assert_equal 10, @aln2.stop
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
    assert_equal 'GGGGCAGCTTGTTCGAAGCGTGACCCCCAAGACGTCGTCCTGACGAGCACAAACTCCCATTGAGAGTGGC', @aln1.sequence
    assert_equal 'AACCGCGGTT', @aln2.sequence
  end

  def test_base_at
    assert_equal 'G', @aln1.base_at(0)
    assert_equal 'C', @aln1.base_at(4)
    assert_equal 'A', @aln1.base_at(5)
    assert_equal '.', @aln1.base_at(70)
    assert_equal 'C', @aln1.base_at(-1)
    assert_equal 'G', @aln1.base_at(-2)
    assert_equal 'G', @aln1.base_at(-70)
    assert_equal '.', @aln1.base_at(-71)
    assert_equal 'A', @aln2.base_at(0)
    assert_equal 'T', @aln2.base_at(9)
    assert_equal '.', @aln2.base_at(10)
  end

  def test_base_qualities
    assert_equal ([17] * 70), @aln1.base_qualities
    assert_equal ([255] * 10), @aln2.base_qualities
  end

  def test_base_quality_at
    assert_equal 17, @aln1.base_quality_at(0)
    assert_equal 17, @aln1.base_quality_at(-1)
    assert_equal 17, @aln1.base_quality_at(69)
    assert_equal 17, @aln1.base_quality_at(-70)
    assert_equal 0, @aln1.base_quality_at(70)
    assert_equal 0, @aln1.base_quality_at(71)
    #    assert_equal ([255] * 10), @aln2.base_qualities
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
