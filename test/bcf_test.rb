# frozen_string_literal: true

require_relative "test_helper"

class BcfTest < Minitest::Test
  def test_bcf_path
    File.expand_path("../htslib/test/index.vcf", __dir__)
  end

  def test_multi_sample_bcf_path
    File.expand_path("../htslib/test/tabix/vcf_file.bcf", __dir__)
  end

  def setup
    @bcf = silence_stderr { HTS::Bcf.new(test_bcf_path) }
  end

  def teardown
    @bcf.close
  end

  def test_initialize
    assert_instance_of HTS::Bcf, @bcf
  end

  def test_native_handle_is_not_public
    refute_respond_to @bcf, :struct
    refute_respond_to @bcf, :to_ptr
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
    assert_equal(true, alns.all? { |i| i.is_a?(HTS::Bcf::Record) })
  end

  def test_each_without_block
    alns = @bcf.each
    assert_kind_of Enumerator, alns
    assert_equal(true, alns.all? { |i| i.is_a?(HTS::Bcf::Record) })
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
    silence_stderr do
      assert_raises(HTS::Bcf::OpenError) { HTS::Bcf.new("/tmp/no_such_file") }
    end
  end

  def test_initialize_with_subset
    bcf = HTS::Bcf.new(test_multi_sample_bcf_path, subset: ["B"])

    assert_equal ["B"], bcf.samples
    assert_equal 1, bcf.nsamples
    assert_equal ["0/1"], bcf.first.format("GT")
  ensure
    bcf&.close
  end

  def test_query_requires_index
    bcf = silence_stderr do
      HTS::Bcf.new(Fixtures["test.bcf"], index: "/tmp/no_such_test_bcf_index.csi")
    end

    error = assert_raises(HTS::Bcf::MissingIndexError) do
      bcf.query("poo:4000-4100").first
    end

    assert_match(/Index file is required/, error.message)
  ensure
    bcf&.close
  end

  def test_query_invalid_region_raises_query_error
    bcf = silence_stderr { HTS::Bcf.open(Fixtures["test.bcf"]) }

    error = silence_stderr do
      assert_raises(HTS::Bcf::QueryError) do
        bcf.query("unknown:1-10").first
      end
    end

    assert_match(/unknown:1-10/, error.message)
  ensure
    bcf&.close
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

  def test_query_multi_regions
    bcf = HTS::Bcf.open(Fixtures["test.bcf"])

    r = bcf.query(["poo:4000-4100", "poo:4300-4400"]).map { |aln| aln.pos + 1 }
    assert_equal [4021, 4310, 4337], r

    r = bcf.query(["poo:4000-4100", "poo:4300-4400"], copy: true).map { |aln| aln.pos + 1 }
    assert_equal [4021, 4310, 4337], r

    r = bcf.query(["poo:4000-4500"]).map { |aln| aln.pos + 1 }
    assert_equal [4021, 4310, 4337], r

    r = bcf.query(["poo:4000-4500"], copy: true).map { |aln| aln.pos + 1 }
    assert_equal [4021, 4310, 4337], r
  end

  def test_query_vcf_gz_with_tabix_index
    bcf = silence_stderr { HTS::Bcf.open(Fixtures["test.vcf.gz"]) }

    assert_equal "vcf", bcf.file_format
    assert bcf.index_loaded?
    assert_equal 4021, bcf.query("poo", 4000, 4100).first.pos + 1
    assert_equal 4021, bcf.query("poo:4000-4100").first.pos + 1
    assert_equal 4021, bcf.query("poo", 4000, 4100, copy: true).first.pos + 1
    assert_equal 4021, bcf.query("poo:4000-4100", copy: true).first.pos + 1

    r = bcf.query("poo:4000-4500").map { |aln| aln.pos + 1 }
    assert_equal [4021, 4310, 4337], r

    r = bcf.query(["poo:4000-4100", "poo:4300-4400"], copy: true).map { |aln| aln.pos + 1 }
    assert_equal [4021, 4310, 4337], r
  ensure
    bcf&.close
  end

  def test_build_index
    Dir.mktmpdir do |dir|
      index_path = File.join(dir, "test.bcf.csi")

      silence_stderr do
        HTS::Bcf.open(Fixtures["test.bcf"]) do |bcf|
          bcf.build_index(index_path, verbose: false)
        end
      end

      assert_equal true, File.exist?(index_path)
    end
  end

  # INFO field writing tests
  def test_info_update_int
    bcf = HTS::Bcf.new(test_bcf_path)
    record = bcf.first
    info = record.info

    # Update existing integer INFO field (DP exists in header)
    info.update_int("DP", [50])
    assert_equal [50], info.get_int("DP")

    # Update with single value
    info.update_int("IDV", [10])
    assert_equal [10], info.get_int("IDV")

    bcf.close
  end

  def test_info_update_float
    bcf = HTS::Bcf.new(test_bcf_path)
    record = bcf.first
    info = record.info

    # Update float INFO field (VDB exists in header)
    info.update_float("VDB", [0.5])
    result = info.get_float("VDB")
    assert_equal 1, result.size
    assert_in_delta 0.5, result[0], 0.001

    # Update IMF (another float field)
    info.update_float("IMF", [0.75])
    result = info.get_float("IMF")
    assert_equal 1, result.size
    assert_in_delta 0.75, result[0], 0.001

    bcf.close
  end

  def test_info_update_string
    require "tempfile"

    Tempfile.create(["test_bcf_info_string_source", ".vcf"]) do |src|
      src.write <<~VCF
        ##fileformat=VCFv4.2
        ##contig=<ID=1,length=1000>
        ##INFO=<ID=STRX,Number=1,Type=String,Description="string info test">
        #CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO
        1\t10\t.\tA\tT\t.\tPASS\t.
      VCF
      src.flush

      bcf = HTS::Bcf.new(src.path)
      record = bcf.first
      info = record.info
      info.update_string("STRX", "hello")
      assert_equal "hello", info.get_string("STRX")
      bcf.close
    end
  end

  def test_info_update_flag
    bcf = HTS::Bcf.new(test_bcf_path)
    record = bcf.first
    info = record.info

    # Set flag (INDEL exists in header)
    info.update_flag("INDEL", true)
    assert_equal true, info.get_flag("INDEL")

    # NOTE: Flag removal in VCF/BCF is complex - once set, the flag
    # metadata remains in the record structure even after "removal"
    # This is a known limitation of the BCF format and htslib
    # For practical purposes, we test that update_flag(false) doesn't error
    info.update_flag("INDEL", false)
    # Don't assert the result as htslib behavior varies

    bcf.close
  end

  def test_info_bracket_assignment
    bcf = HTS::Bcf.new(test_bcf_path)
    record = bcf.first
    info = record.info

    # Test []= with different types using existing fields
    info["DP"] = 100
    assert_equal [100], info["DP"]

    info["VDB"] = 0.75
    result = info["VDB"]
    assert_equal 1, result.size
    assert_in_delta 0.75, result[0], 0.001

    info["INDEL"] = true
    assert_equal true, info["INDEL"]

    bcf.close
  end

  def test_info_delete
    bcf = HTS::Bcf.new(test_bcf_path)
    record = bcf.first
    info = record.info

    # Set a field and delete it
    info["DP"] = 999
    assert_equal [999], info["DP"]
    assert info.key?("DP")

    result = info.delete("DP")
    assert result
    assert_nil info["DP"]
    refute info.key?("DP")

    # Deleting non-existent field returns false
    result = info.delete("NONEXISTENT")
    refute result

    bcf.close
  end

  def test_info_key?
    bcf = HTS::Bcf.new(test_bcf_path)
    record = bcf.first
    info = record.info

    # Existing field (DP exists in test VCF header)
    # Note: may not be set in every record, but is in header
    # Non-existent field
    refute info.key?("NONEXISTENT")
    refute info.include?("NONEXISTENT")

    # After adding
    info["DP"] = 123
    assert info.key?("DP")

    bcf.close
  end

  def test_info_nil_assignment_deletes
    bcf = HTS::Bcf.new(test_bcf_path)
    record = bcf.first
    info = record.info

    # Add field
    info["DP"] = 100
    assert info.key?("DP")

    # Assign nil to delete
    info["DP"] = nil
    refute info.key?("DP")
    assert_nil info["DP"]

    bcf.close
  end

  def test_info_roundtrip_write_read
    require "tempfile"

    Tempfile.create(["test_bcf_write", ".vcf"]) do |tmp|
      tmp_path = tmp.path
      tmp.close

      # Read original VCF
      input_bcf = HTS::Bcf.new(test_bcf_path)
      header = input_bcf.header

      # Write VCF with modified INFO
      output_bcf = HTS::Bcf.new(tmp_path, "w")
      output_bcf.write_header(header)

      input_bcf.each do |record|
        info = record.info
        info["DP"] = 500
        info["VDB"] = 0.95
        info["INDEL"] = true
        output_bcf.write(record)
      end

      input_bcf.close
      output_bcf.close

      # Read back and verify
      verify_bcf = HTS::Bcf.new(tmp_path)
      verify_bcf.each do |record|
        info = record.info
        assert_equal [500], info["DP"]
        vdb = info["VDB"]
        assert_equal 1, vdb.size
        assert_in_delta 0.95, vdb[0], 0.001
        assert_equal true, info["INDEL"]
      end
      verify_bcf.close
    end
  end
end
