require_relative '../test_helper'

class AlignmentTest < Minitest::Test
  def setup
    @bam = HTS::Bam.new(File.expand_path('../assets/poo.sort.bam', __dir__))
    @alm1 = @bam.first
  end

  def test_qname
    assert_equal 'poo_3290_3833_2:0:0_2:0:0_119', @alm1.qname
  end

  def test_rnext
    assert_equal 'poo', @alm1.rnext
  end

  def test_pnext
    assert_equal 3289, @alm1.pnext
  end

  def test_rname
    assert_equal 'poo', @alm1.rname
  end

  def test_strand
    assert_equal '+', @alm1.strand
  end

  def test_base_qualities
    assert_equal ([17] * 70), @alm1.base_qualities
  end

  def test_pos
    assert_equal 3289, @alm1.pos
  end

  def test_isize
    assert_equal 0, @alm1.isize
  end

  def test_mapping_quality
    assert_equal 0, @alm1.mapping_quality
  end

  def test_cigar
    assert_instance_of HTS::Bam::Cigar, @alm1.cigar
  end

  def test_qlen
    assert_equal 0, @alm1.qlen # Is that right?
  end

  def test_rlen
    assert_equal 0, @alm1.rlen # Is that right?
  end
end
