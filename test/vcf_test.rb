# frozen_string_literal: true

require_relative "test_helper"

class VCFTest < Minitest::Test
  def vcf_path
    File.expand_path("../htslib/test/index.vcf", __dir__)
  end

  def setup
    @vcf = HTS::VCF.new(vcf_path)
  end

  def test_initialize
    assert_instance_of HTS::VCF, @vcf
  end

  def test_file_path
    assert_equal vcf_path, @vcf.file_path
  end

  def test_header
    assert_instance_of HTS::VCF::Header, @vcf.header
  end

  def test_n_samples
    assert_equal 1, @vcf.n_samples
  end

  def test_each
    alns = @vcf.to_a
    assert_equal true, alns.all? { |i| i.is_a?(HTS::VCF::Variant) }
  end
end
