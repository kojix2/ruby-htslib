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
    @bcf.close
  end

  def test_initialize
    assert_instance_of HTS::Bcf, @bcf
  end

  def test_file_name
    assert_equal test_bcf_path, @bcf.file_name
  end

  def test_mode
    assert_equal "r", @bcf.mode
  end

  def test_header
    assert_instance_of HTS::Bcf::Header, @bcf.header
  end

  def test_file_format
    assert_equal "vcf", @bcf.file_format
  end

  def test_file_format_version
    assert_equal "4.2", @bcf.file_format_version
  end

  def test_nsamples
    assert_equal 1, @bcf.nsamples
  end

  def test_samples
    assert_equal ["ERS220911"], @bcf.samples
  end

  def test_each
    alns = @bcf.to_a
    assert_equal true, (alns.all? { |i| i.is_a?(HTS::Bcf::Record) })
  end

  # def test_initialize_no_file
  #   assert_raises(StandardError) { HTS::Bcf.new("/tmp/no_such_file") }
  # end
end
