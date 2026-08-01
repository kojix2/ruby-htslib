# frozen_string_literal: true

require_relative "../test_helper"
require "tempfile"
require "tmpdir"

class BamRecordBuildTest < Minitest::Test
  HEADER_TEXT = <<~SAM
    @HD\tVN:1.6\tSO:unsorted
    @SQ\tSN:chr1\tLN:1000
    @RG\tID:rg1\tSM:sample1
  SAM

  def setup
    @header = HTS::Bam::Header.parse(HEADER_TEXT)
  end

  def test_builds_a_record_from_ruby_values
    record = HTS::Bam::Record.new(
      @header,
      qname: "read1",
      chrom: "chr1",
      pos: 9,
      mapq: 60,
      cigar: "4M",
      sequence: "ACGT",
      qualities: [30, 31, 32, 33],
      aux: { "NM" => 0, "RG" => "rg1" }
    )

    assert_equal "read1", record.qname
    assert_equal 0, record.tid
    assert_equal "chr1", record.chrom
    assert_equal 9, record.pos
    assert_equal 60, record.mapq
    assert_equal "4M", record.cigar.to_s
    assert_equal "ACGT", record.sequence
    assert_equal [30, 31, 32, 33], record.qual
    assert_equal "?@AB", record.qual_string
    assert_equal({ "NM" => 0, "RG" => "rg1" }, record.aux.to_h)
  end

  def test_accepts_quality_string_and_reference_setters
    record = HTS::Bam::Record.new(
      @header, qname: "read2", cigar: "2M", seq: "TG", quality_string: "II"
    )

    record.chrom = "chr1"
    record.mate_chrom = "chr1"

    assert_equal [40, 40], record.qual
    assert_equal 0, record.tid
    assert_equal 0, record.mtid
  end

  def test_writes_and_reads_constructed_records
    mapped = HTS::Bam::Record.new(
      @header, qname: "mapped", chrom: "chr1", pos: 99, mapq: 42,
      cigar: "5M", sequence: "AACGT", qualities: [10, 20, 30, 40, 50],
      aux: { "NM" => 1 }
    )
    unmapped = HTS::Bam::Record.new(
      @header, qname: "unmapped", flag: HTS::Bam::Flag::UNMAPPED,
      sequence: "NN", qualities: nil
    )

    Tempfile.create(["constructed", ".bam"]) do |file|
      path = file.path
      file.close
      HTS::Bam.open(path, "wb") do |bam|
        bam.write_header(@header)
        bam << mapped
        bam << unmapped
      end

      records = nil
      HTS::Bam.open(path) { |bam| records = bam.each(copy: true).to_a }
      assert_equal %w[mapped unmapped], records.map(&:qname)
      assert_equal ["AACGT", "NN"], records.map(&:sequence)
      assert_equal [10, 20, 30, 40, 50], records.first.qual
      assert_equal 1, records.first.aux["NM"]
      assert records.last.unmapped?
      assert_equal [255, 255], records.last.qual
    end
  end

  def test_rejects_inconsistent_values
    assert_raises(ArgumentError) do
      HTS::Bam::Record.new(@header, cigar: "3M", sequence: "AC", qualities: [30, 30])
    end
    assert_raises(ArgumentError) do
      HTS::Bam::Record.new(@header, sequence: "AC", qualities: [30])
    end
    assert_raises(ArgumentError) do
      HTS::Bam::Record.new(@header, chrom: "missing")
    end
    assert_raises(RangeError) do
      HTS::Bam::Record.new(@header, mapq: 256)
    end
  end

  def test_constructed_coordinate_sorted_bam_can_be_indexed_and_queried
    header = HTS::Bam::Header.parse(HEADER_TEXT.sub("SO:unsorted", "SO:coordinate"))
    records = [10, 100].map.with_index do |position, index|
      HTS::Bam::Record.new(
        header, qname: "read#{index + 1}", chrom: "chr1", pos: position,
        mapq: 60, cigar: "3M", sequence: "ACG", qualities: [30, 30, 30]
      )
    end

    Dir.mktmpdir do |dir|
      path = File.join(dir, "generated.bam")
      HTS::Bam.open(path, "wb") do |bam|
        bam.write_header(header)
        records.each { |record| bam << record }
      end
      HTS::Bam.build_index(path, nil, 0, 0, false)

      names = []
      HTS::Bam.open(path) { |bam| bam.query("chr1:1-50") { |record| names << record.qname } }
      assert_equal ["read1"], names
    end
  end
end
