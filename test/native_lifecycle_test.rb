# frozen_string_literal: true

require_relative "test_helper"

class NativeLifecycleTest < Minitest::Test
  def test_bam_record_duplication_has_independent_storage
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      original = bam.first.dup
      copy = original.dup
      copy.qname = "changed"

      refute_equal original.qname, copy.qname
      assert_equal "changed", copy.qname
    end
  end

  def test_bcf_record_retains_header_after_file_is_closed_and_collected
    bcf = HTS::Bcf.new(File.expand_path("../htslib/test/tabix/vcf_file.bcf", __dir__))
    record = bcf.each(copy: true).first
    expected = record.to_s
    bcf.close
    nil
    GC.start

    assert_equal expected, record.to_s
  end

  def test_native_file_close_is_idempotent
    bam = HTS::Bam.new(Fixtures["moo.bam"])
    bcf = HTS::Bcf.new(File.expand_path("../htslib/test/tabix/vcf_file.bcf", __dir__))
    tabix = HTS::Tabix.new(Fixtures["test.vcf.gz"])
    faidx = HTS::Faidx.new(Fixtures["random.fa"])

    [bam, bcf, tabix, faidx].each do |file|
      assert_nil file.close
      assert_nil file.close
      assert file.closed?
    end
  end

  def test_bam_close_reports_buffered_write_failure
    skip "/dev/full is unavailable" unless File.exist?("/dev/full")

    bam = HTS::Bam.new("/dev/full", "wb")
    bam.write_header(HTS::Bam::Header.parse("@HD\tVN:1.6\n"))

    assert_raises(HTS::Bam::WriteError) { bam.close }
    assert bam.closed?
    assert_nil bam.close
  end

  def test_bcf_close_reports_buffered_write_failure
    skip "/dev/full is unavailable" unless File.exist?("/dev/full")

    bcf = HTS::Bcf.new("/dev/full", "wb")
    header = HTS::Bcf::Header.new
    header.append("##fileformat=VCFv4.3")
    header.sync
    bcf.write_header(header)

    assert_raises(HTS::Bcf::WriteError) { bcf.close }
    assert bcf.closed?
    assert_nil bcf.close
  end

  def test_mpileup_keeps_input_objects_alive
    bam = HTS::Bam.new(Fixtures["moo.bam"])
    mpileup = HTS::Bam::Mpileup.new([bam], overlaps: true)
    nil
    GC.start

    refute_nil mpileup.first
  ensure
    mpileup&.close
  end

  def test_tabix_cannot_be_closed_from_inside_native_query
    tabix = HTS::Tabix.new(Fixtures["test.vcf.gz"])

    assert_raises(IOError) { tabix.query("poo:4020-4022") { tabix.close } }
    refute tabix.closed?
  ensure
    tabix&.close
  end
end
