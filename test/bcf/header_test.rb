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
    @bcf.close
  end

  def test_get_version
    assert_equal "VCFv4.1", @hdr.get_version
  end

  def test_nsamples
    assert_equal 2, @hdr.nsamples
  end

  def test_samples
    assert_equal %w[A B], @hdr.samples
  end

  def test_add_sample
    hdr2 = @hdr.clone
    hdr2.add_sample("kojix2")
    hdr2.add_sample("kojix3")
    assert_equal 4, hdr2.nsamples
    assert_equal %w[A B kojix2 kojix3], hdr2.samples
  end

  def test_sync
    hdr2 = @hdr.clone
    hdr2.add_sample("kojix2", sync: false)
    hdr2.add_sample("kojix3", sync: false)
    assert_equal 2, hdr2.nsamples
    assert_equal %w[A B], hdr2.samples
    hdr2.sync
    assert_equal 4, hdr2.nsamples
    assert_equal %w[A B kojix2 kojix3], hdr2.samples
  end

  def test_to_s
    require "digest/md5"
    str = @hdr.to_s
    md5sum = Digest::MD5.hexdigest(str)
    assert_equal "b99a81dee4a8db317146e6341a8ae42a", md5sum
  end
end
