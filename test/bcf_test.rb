# frozen_string_literal: true

require_relative "test_helper"

class BcfTest < Minitest::Test
  def test_bcf_path
    File.expand_path("../htslib/test/index.vcf", __dir__)
  end

  def setup
    @bcf = HTS::Bcf.new(test_bcf_path)
  end

  def teardown
    @bcf&.close
  end

  def test_initialize
    assert_instance_of HTS::Bcf, @bcf
  end

  def test_file_path
    assert_equal test_bcf_path, @bcf.file_path
  end

  def test_header
    assert_instance_of HTS::Bcf::Header, @bcf.header
  end

  def test_sample_count
    assert_equal 1, @bcf.sample_count
  end

  def test_samples
    assert_equal ["ERS220911"], @bcf.samples
  end

  def test_each
    alns = @bcf.to_a
    assert_equal true, (alns.all? { |i| i.is_a?(HTS::Bcf::Record) })
  end
end
