require_relative 'test_helper'

class FaiTest < Minitest::Test
  def setup
    @fai = HTS::Fai.new(File.expand_path('fixtures/random.fa', __dir__))
  end

  def test_initialize_fai
    assert_instance_of HTS::Fai, @fai
  end

  def test_size
    assert_equal 5, @fai.size
  end

  def test_length
    assert_equal 5, @fai.length
  end

  def test_chrom_size
    assert_equal 500, @fai.chrom_size('chr1')
    assert_equal 500, @fai.chrom_size(:chr1)
    assert_raises(ArgumentError){ @fai.chrom_size(nil) }
    assert_nil @fai.chrom_size('chr')
  end

  def test_chrom_length
    assert_equal 500, @fai.chrom_length('chr1')
    assert_equal 500, @fai.chrom_length(:chr1)
    assert_raises(ArgumentError){ @fai.chrom_length(nil) }
    assert_nil @fai.chrom_length('chr')
  end
end
