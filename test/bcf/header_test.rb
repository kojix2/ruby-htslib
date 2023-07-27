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

  def test_initialize_with_block
    assert_instance_of HTS::Bcf::Header, HTS::Bcf::Header.new do |h|
      assert_instance_of HTS::Bcf::Header, h
    end
  end

  def test_get_version
    assert_equal "VCFv4.1", @hdr.get_version
  end

  def test_set_version
    hdr2 = @hdr.clone
    hdr2.set_version("VCFv9.9")
    assert_equal "VCFv9.9", hdr2.get_version
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
    hdr2.add_sample("kojix1", sync: false)
    hdr2.add_sample("kojix2", sync: false)
    hdr2.add_sample("kojix3", sync: false)
    assert_equal 2, hdr2.nsamples
    assert_equal %w[A B], hdr2.samples
    hdr2.sync
    assert_equal 5, hdr2.nsamples
    assert_equal %w[A B kojix1 kojix2 kojix3], hdr2.samples
  end

  def test_append_delete
    h = HTS::Bcf::Header.new
    h.append('##FILTER=<ID=Nessie,Description="Nessie is a creature in Scottish folklore that is said to inhabit Loch Ness in the Scottish Highlands.">')
    h.delete("FILTER", "Nessie")
  end

  def test_seqnames
    assert_equal %w[1 2 3 4], @hdr.seqnames
  end

  def test_to_s
    require "digest/md5"
    str = @hdr.to_s
    md5sum = Digest::MD5.hexdigest(str)
    assert_equal "b99a81dee4a8db317146e6341a8ae42a", md5sum
  end

  def test_name2id
    assert_equal 0, @hdr.name2id("1")
    assert_equal 1, @hdr.name2id("2")
    assert_equal 2, @hdr.name2id("3")
    assert_equal 3, @hdr.name2id("4")
    assert_equal(-1, @hdr.name2id("5")) # FIXME?
  end

  def test_id2name
    assert_equal "1", @hdr.id2name(0)
    assert_equal "2", @hdr.id2name(1)
    assert_equal "3", @hdr.id2name(2)
    assert_equal "4", @hdr.id2name(3)
    assert_nil @hdr.id2name(4)
  end
end
