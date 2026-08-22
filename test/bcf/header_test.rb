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
    yielded = nil
    header = HTS::Bcf::Header.new do |h|
      yielded = h
    end

    assert_instance_of HTS::Bcf::Header, header
    assert_same header, yielded
  end

  def test_get_version
    assert_equal "VCFv4.1", @hdr.get_version
    assert_equal "VCFv4.1", @hdr.version
  end

  def test_set_version
    hdr2 = @hdr.clone
    hdr2.set_version("VCFv9.9")
    assert_equal "VCFv9.9", hdr2.get_version
    hdr2.version = "VCFv9.8"
    assert_equal "VCFv9.8", hdr2.version
    assert hdr2.to_s.start_with?("##fileformat=VCFv9.8\n")
    assert_equal 1, hdr2.to_s.scan(/^##fileformat=/).length
  end

  def test_nsamples
    assert_equal 2, @hdr.nsamples
  end

  def test_target_count
    assert_equal 4, @hdr.target_count
  end

  def test_target_name
    assert_equal "1", @hdr.target_name(0)
    assert_equal "4", @hdr.target_name(3)
    assert_nil @hdr.target_name(4)
  end

  def test_target_names
    assert_equal %w[1 2 3 4], @hdr.target_names
  end

  def test_get_tid
    assert_equal 0, @hdr.get_tid("1")
    assert_equal 3, @hdr.get_tid("4")
    assert_equal(-1, @hdr.get_tid("5"))
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

  def test_subset_returns_new_header
    subset = @hdr.subset(["B"])

    assert_equal %w[A B], @hdr.samples
    assert_equal ["B"], subset.samples
    assert_equal 1, subset.nsamples
  end

  def test_subset_rejects_unknown_samples
    error = assert_raises(HTS::Bcf::UnknownSampleError) do
      @hdr.subset(["missing"])
    end

    assert_match(/missing/, error.message)
  end

  def test_subset_rejects_duplicates
    error = assert_raises(HTS::Bcf::SubsetError) do
      @hdr.subset(%w[A A])
    end

    assert_match(/Duplicate sample names/, error.message)
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

  def test_get_hrec_returns_owned_copy
    hrec = @hdr.get_hrec("FILTER", "ID", "PASS")

    assert_instance_of HTS::Bcf::HeaderRecord, hrec
    refute_respond_to hrec, :struct
    refute_respond_to hrec, :to_ptr
    assert_equal '##FILTER=<ID=PASS,Description="All filters passed">', hrec.to_s.chomp
  end

  def test_header_record_copy_owns_duplicated_hrec
    hrec = @hdr.get_hrec("FILTER", "ID", "PASS")
    copy = hrec.dup

    refute_same hrec, copy
    refute_respond_to copy, :struct
    assert_equal hrec.to_s, copy.to_s
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

  def test_edit_batches_sync
    hdr2 = @hdr.clone

    hdr2.edit do |header|
      header.add_sample("kojix4")
      header.add_sample("kojix5")
      header.add_filter("BatchFilter", description: "batch-added")
    end

    assert_equal %w[A B kojix4 kojix5], hdr2.samples
    assert_match(/##FILTER=<ID=BatchFilter,Description="batch-added">/, hdr2.to_s)
  end

  def test_add_and_remove_contig
    h = HTS::Bcf::Header.new
    h.add_contig("chr1", length: 1000, assembly: "GRCh38")

    assert_equal ["chr1"], h.target_names
    assert_match(/##contig=<ID=chr1,length=1000,assembly=GRCh38>/, h.to_s)

    assert_equal true, h.remove_contig("chr1")
    assert_equal [], h.target_names
  end

  def test_add_update_remove_info_and_format
    h = HTS::Bcf::Header.new
    h.add_info("DP", number: 1, type: :int, description: "Total depth")
    h.add_format("GT", number: 1, type: :string, description: "Genotype")

    assert_match(/##INFO=<ID=DP,Number=1,Type=Integer,Description="Total depth">/, h.to_s)
    assert_match(/##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">/, h.to_s)

    h.update_info("DP", number: 1, type: :int, description: "Read depth")
    h.update_format("GT", number: 1, type: :string, description: "GT field")
    assert_match(/##INFO=<ID=DP,Number=1,Type=Integer,Description="Read depth">/, h.to_s)
    assert_match(/##FORMAT=<ID=GT,Number=1,Type=String,Description="GT field">/, h.to_s)

    assert_equal true, h.remove_info("DP")
    assert_equal true, h.remove_format("GT")
    refute_match(/##INFO=<ID=DP/, h.to_s)
    refute_match(/##FORMAT=<ID=GT/, h.to_s)
  end

  def test_add_meta_and_filter
    h = HTS::Bcf::Header.new
    h.add_meta("source", "myCaller")
    h.add_filter("LowQual", description: "Low quality")

    assert_match(/##source=myCaller/, h.to_s)
    assert_match(/##FILTER=<ID=LowQual,Description="Low quality">/, h.to_s)

    assert_equal true, h.remove_filter("LowQual")
    refute_match(/LowQual/, h.to_s)
  end
end
