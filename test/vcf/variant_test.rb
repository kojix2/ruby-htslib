# frozen_string_literal: true

require_relative '../test_helper'

class VariantTest < Minitest::Test
  def vcf_path
    File.expand_path('../../htslib/test/tabix/vcf_file.bcf', __dir__)
  end

  def setup
    @vcf = HTS::VCF.new(vcf_path)
    @v0, @v1 = @vcf.first(2)
  end

  def test_pos
    assert_equal 3_000_151, @v0.pos
  end

  def test_start
    assert_equal 3_000_150, @v0.start
  end

  def test_stop
    assert_equal 3_000_151, @v0.stop
  end

  # def test_id
  #   assert_equal nil, @v1.id
  # end

  def test_qual
    assert_in_epsilon 59.2, @v1.qual
  end

  def test_ref
    assert_equal 'C', @v1.ref
  end
end
