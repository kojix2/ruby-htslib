# frozen_string_literal: true

require_relative "test_helper"

class BcfTest < Minitest::Test
  def bcf_path
    File.expand_path("../htslib/test/index.vcf", __dir__)
  end

  def setup
    @bcf = HTS::Bcf.new(bcf_path)
  end

  def test_initialize
    assert_instance_of HTS::Bcf, @bcf
  end

  def test_file_path
    assert_equal bcf_path, @bcf.file_path
  end

  def test_header
    assert_instance_of HTS::Bcf::Header, @bcf.header
  end

  def test_n_samples
    assert_equal 1, @bcf.n_samples
  end

  def test_each
    alns = @bcf.to_a
    assert_equal true, alns.all? { |i| i.is_a?(HTS::Bcf::Record) }
  end
end
