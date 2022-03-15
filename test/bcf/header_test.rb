# frozen_string_literal: true

require_relative "../test_helper"

class BcfHeaderTest < Minitest::Test
  def test_bcf_path
    File.expand_path("../../htslib/test/tabix/vcf_file.bcf", __dir__)
  end

  def setup
    @bcf = HTS::Bcf.new(test_bcf_path)
    @hdr = @bcf.header
  end

  def teardown
    @bcf&.close
  end

  def test_get_version
    assert_equal "VCFv4.1", @hdr.get_version
  end

  def test_sample_count
    assert_equal 2, @hdr.sample_count
  end

  def test_sample_names
    assert_equal ["A", "B"], @hdr.sample_names
  end

  def test_to_s
    require "digest/md5"
    str = @hdr.to_s
    md5sum = Digest::MD5.hexdigest(str)
    assert_equal "b99a81dee4a8db317146e6341a8ae42a", md5sum
  end
end
