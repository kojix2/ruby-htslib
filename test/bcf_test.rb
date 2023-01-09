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

  def test_struct
    assert_equal false, @bcf.struct.null?
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

  def test_each_with_block
    alns = []
    @bcf.each do |aln|
      alns << aln
    end
    assert_equal true, (alns.all? { |i| i.is_a?(HTS::Bcf::Record) })
  end

  def test_each_without_block
    alns = @bcf.each
    assert_kind_of Enumerator, alns
    assert_equal true, (alns.all? { |i| i.is_a?(HTS::Bcf::Record) })
  end

  def test_chrom
    act = @bcf.chrom
    exp = @bcf.map(&:chrom)
    assert_equal exp, act
  end

  def test_pos
    act = @bcf.pos
    exp = @bcf.map(&:pos)
    assert_equal exp, act
  end

  def test_endpos
    act = @bcf.endpos
    exp = @bcf.map(&:endpos)
    assert_equal exp, act
  end

  def test_id
    act = @bcf.id
    exp = @bcf.map(&:id)
    assert_equal exp, act
  end

  def test_ref
    act = @bcf.ref
    exp = @bcf.map(&:ref)
    assert_equal exp, act
  end

  def test_alt
    act = @bcf.alt
    exp = @bcf.map(&:alt)
    assert_equal exp, act
  end

  def test_qual
    act = @bcf.qual
    exp = @bcf.map(&:qual)
    assert_equal exp, act
  end

  def test_filter
    act = @bcf.filter
    exp = @bcf.map(&:filter)
    assert_equal exp, act
  end

  def test_info
    act = @bcf.info("AN")
    exp = @bcf.map { |r| r.info("AN") }
    assert_equal exp, act
  end

  def test_format
    act = @bcf.format("DP")
    exp = @bcf.map { |r| r.format("DP") }
    assert_equal exp, act
  end

  def test_initialize_no_file_bcf
    stderr_old = $stderr.dup
    $stderr.reopen(File::NULL)
    assert_raises(Errno::ENOENT) { HTS::Bcf.new("/tmp/no_such_file") }
    $stderr.flush
    $stderr.reopen(stderr_old)
  end

  def test_query
    bcf = HTS::Bcf.open(Fixtures["test.bcf"])
    assert_equal 4021, bcf.query("poo", 4000, 4100).first.pos + 1
    assert_equal 4021, bcf.query("poo:4000-4100").first.pos + 1
    assert_equal 4021, bcf.query("poo", 4000, 4100, copy: true).first.pos + 1
    assert_equal 4021, bcf.query("poo:4000-4100", copy: true).first.pos + 1
    assert_raises(ArgumentError) { bcf.query("poo", 4000) }
    bcf.query("poo", 4000, 4100) do |aln|
      assert_equal 4021, aln.pos + 1
    end
    bcf.query("poo:4000-4100") do |aln|
      assert_equal 4021, aln.pos + 1
    end
    bcf.query("poo", 4000, 4100, copy: true) do |aln|
      assert_equal 4021, aln.pos + 1
    end
    bcf.query("poo:4000-4100", copy: true) do |aln|
      assert_equal 4021, aln.pos + 1
    end
    r = bcf.query("poo", 4000, 4500).map do |aln|
      aln.pos + 1
    end
    assert_equal [4021, 4310, 4337], r
    r = bcf.query("poo:4000-4500").map do |aln|
      aln.pos + 1
    end
    assert_equal [4021, 4310, 4337], r
    r = bcf.query("poo", 4000, 4500, copy: true).map do |aln|
      aln.pos + 1
    end
    assert_equal [4021, 4310, 4337], r
    r = bcf.query("poo:4000-4500", copy: true).map do |aln|
      aln.pos + 1
    end
    assert_equal [4021, 4310, 4337], r
  end
end
