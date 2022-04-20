# frozen_string_literal: true

require_relative "../test_helper"

class BamRecordTest < Minitest::Test
  def setup
    bam1 = HTS::Bam.new(Fixtures["poo.sort.bam"])
    @aln1 = bam1.first
    bam2 = HTS::Bam.new(File.expand_path("../../htslib/test/colons.bam", __dir__))
    @aln2 = bam2.first
  end

  def test_qname
    assert_equal "poo_3290_3833_2:0:0_2:0:0_119", @aln1.qname
    assert_equal "chr1", @aln2.qname
  end

  def test_tid
    assert_equal 0, @aln1.tid
    assert_equal 0, @aln2.tid
  end

  def test_tid=
    assert_equal 0, @aln1.tid
    @aln1.tid = 1
    assert_equal 1, @aln1.tid
    @aln1.tid = 0
    assert_equal 0, @aln1.tid
  end

  def test_mtid
    assert_equal 0, @aln1.mtid
    assert_equal(-1, @aln2.mtid)
  end

  def test_mtid=
    assert_equal 0, @aln1.mtid
    @aln1.mtid = 1
    assert_equal 1, @aln1.mtid
    @aln1.mtid = 0
    assert_equal 0, @aln1.mtid
  end

  def test_pos
    assert_equal 3289, @aln1.pos
    assert_equal 0, @aln2.pos
  end

  def test_pos=
    assert_equal 3289, @aln1.pos
    @aln1.pos = 3290
    assert_equal 3290, @aln1.pos
    @aln1.pos = 3289
    assert_equal 3289, @aln1.pos
  end

  def test_mpos
    assert_equal 3289, @aln1.mpos
    assert_equal(-1, @aln2.mpos)
  end

  def test_mpos=
    assert_equal 3289, @aln1.mpos
    @aln1.mpos = 3290
    assert_equal 3290, @aln1.mpos
    @aln1.mpos = 3289
    assert_equal 3289, @aln1.mpos
  end

  def test_bin
    assert_equal 4681, @aln1.bin
    assert_equal 4681, @aln2.bin
  end

  def test_bin=
    assert_equal 4681, @aln1.bin
    @aln1.bin = 4682
    assert_equal 4682, @aln1.bin
    @aln1.bin = 4681
    assert_equal 4681, @aln1.bin
  end

  def test_chrom
    assert_equal "poo", @aln1.chrom
    assert_equal "chr1", @aln2.chrom
  end

  def test_contig
    assert_equal "poo", @aln1.contig
    assert_equal "chr1", @aln2.contig
  end

  def test_mate_chrom
    assert_equal "poo", @aln1.mate_chrom
    assert_equal "", @aln2.mate_chrom
  end

  def test_stop
    assert_equal 3290, @aln1.stop # may be strange?
    assert_equal 10, @aln2.stop
  end

  def test_strand
    assert_equal "+", @aln1.strand
    assert_equal "+", @aln2.strand
  end

  def test_insert_size
    assert_equal 0, @aln1.insert_size
    assert_equal 0, @aln2.insert_size
  end

  def test_mapq
    assert_equal 0, @aln1.mapq
    assert_equal 0, @aln2.mapq
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
    assert_equal "GGGGCAGCTTGTTCGAAGCGTGACCCCCAAGACGTCGTCCTGACGAGCACAAACTCCCATTGAGAGTGGC", @aln1.sequence
    assert_equal "AACCGCGGTT", @aln2.sequence
  end

  def test_base_at
    assert_equal "G", @aln1.base_at(0)
    assert_equal "C", @aln1.base_at(4)
    assert_equal "A", @aln1.base_at(5)
    assert_equal ".", @aln1.base_at(70)
    assert_equal "C", @aln1.base_at(-1)
    assert_equal "G", @aln1.base_at(-2)
    assert_equal "G", @aln1.base_at(-70)
    assert_equal ".", @aln1.base_at(-71)
    assert_equal "A", @aln2.base_at(0)
    assert_equal "T", @aln2.base_at(9)
    assert_equal ".", @aln2.base_at(10)
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
    assert_equal "PAIRED,UNMAP,READ2", @aln1.flag_str
    assert_equal "", @aln2.flag_str
  end

  def test_flag
    assert_instance_of HTS::Bam::Flag, @aln1.flag
    assert_equal 133, @aln1.flag.value
    assert_equal 0, @aln2.flag.value
  end

  def test_tag
    assert_equal "70M", @aln1.tag("MC")
    assert_equal 0, @aln1.tag("AS")
    assert_equal 0, @aln1.tag("XS")
    assert_nil @aln1.tag("Tanuki")
  end

  def test_to_s
    assert_equal "poo_3290_3833_2:0:0_2:0:0_119\t133\tpoo\t3290\t0\t*\t=\t3290\t0\tGGGGCAGCTTGTTCGAAGCGTGACCCCCAAGACGTCGTCCTGACGAGCACAAACTCCCATTGAGAGTGGC\t2222222222222222222222222222222222222222222222222222222222222222222222\tMC:Z:70M\tAS:i:0\tXS:i:0",
                 @aln1.to_s
    assert_equal "chr1\t0\tchr1\t1\t0\t10M\t*\t0\t0\tAACCGCGGTT\t*",
                 @aln2.to_s
  end
end
