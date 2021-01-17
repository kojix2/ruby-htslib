require_relative '../test_helper'

class AlignmentTest < Minitest::Test
  def setup
    @bam = HTS::Bam.new(File.expand_path('../assets/poo.sort.bam', __dir__))
    @alignment = @bam.first
  end

  def test_qname
    assert_equal 'poo_3290_3833_2:0:0_2:0:0_119', @alignment.qname
  end

  def test_rnext
    assert_equal 'poo', @alignment.rnext
  end

  def test_pnext
    assert_equal 3289, @alignment.pnext
  end

  def test_rname
    assert_equal "poo", @alignment.rname
  end

  def test_strand
    assert_equal '+', @alignment.strand
  end
end
