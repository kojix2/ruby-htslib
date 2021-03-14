# frozen_string_literal: true

require_relative '../test_helper'

class VariantTest < Minitest::Test
  def vcf_path
    File.expand_path('../../htslib/test/index.vcf', __dir__)
  end

  def setup
    @vcf = HTS::VCF.new(vcf_path)
    @v1 = @vcf.first
  end

  def test_pos
    assert_equal 9999919, @v1.pos
  end

  def test_start
    assert_equal 9999918, @v1.start
  end

  def test_stop
    assert_equal 9999919, @v1.stop
  end
end