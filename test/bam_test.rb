# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"

class BamTest < Minitest::Test
  def test_to_a_materializes_independent_records
    records = HTS::Bam.open(Fixtures["moo.bam"], &:to_a)

    assert_operator records.length, :>, 1
    assert_equal records.length, records.map(&:object_id).uniq.length
    assert_operator records.map(&:pos).uniq.length, :>, 1
  end

  def teardown
    %w[bam sam cram].each do |format|
      %w[string uri].each do |type|
        eval "@#{format}_#{type}&.close"
      end
    end
  end

  def bam(ft)
    public_send(ft.to_s)
  end

  def bam_path(ft)
    public_send("path_#{ft}")
  end

  # Helper method for CRAM tests that require separate instances
  def assert_cram_getter_equal(ft, method_name, &block)
    bam1 = HTS::Bam.new(bam_path(ft))
    bam2 = HTS::Bam.new(bam_path(ft))
    begin
      if block_given?
        act = block.call(bam1)
        exp = bam2.map { |r| block.call(r) }
      else
        act = bam1.public_send(method_name)
        exp = bam2.map(&method_name)
      end

      assert_equal exp.length, act.length

      # Handle different data types appropriately
      if act.any? { |x| x.nil? }
        # For aux data with nil values
        assert_equal exp.compact.sort, act.compact.sort
        assert_equal exp.count(nil), act.count(nil)
      else
        assert_equal exp.sort, act.sort
      end
    ensure
      bam1.close
      bam2.close
    end
  end

  %w[bam sam cram].each do |format|
    define_method "path_#{format}_string" do
      Fixtures["moo.#{format}"]
    end

    define_method "path_#{format}_uri" do
      "https://raw.githubusercontent.com/kojix2/ruby-htslib/develop/test/fixtures/moo.#{format}"
    end
  end

  %w[bam sam cram].each do |format|
    %w[string uri].each do |type|
      ft = "#{format}_#{type}"

      define_method ft.to_s do
        eval("@#{ft} ||= HTS::Bam.new(public_send(\"path_#{ft}\"))")
      end

      define_method "test_new_#{ft}" do
        b = HTS::Bam.new(bam_path(ft))
        assert_instance_of HTS::Bam, b
        b.close
        assert_equal true, b.closed?
      end

      define_method "test_open_#{ft}" do
        b = HTS::Bam.open(bam_path(ft))
        assert_instance_of HTS::Bam, b
        assert_equal false, b.closed?
        b.close
        assert_equal true, b.closed?
        assert_nil b.close
      end

      define_method "test_open_#{ft}_with_block" do
        result = HTS::Bam.open(bam_path(ft)) do |b|
          assert_instance_of HTS::Bam, b
          :block_result
        end
        assert_equal :block_result, result
      end

      define_method "test_native_handle_is_not_public_#{ft}" do
        refute_respond_to bam(ft), :struct
        refute_respond_to bam(ft), :to_ptr
      end

      define_method "test_file_name_#{ft}" do
        assert_equal bam_path(ft),
                     bam(ft).file_name
      end

      define_method "test_mode_#{ft}" do
        assert_equal "r", bam(ft).mode
      end

      define_method "test_header_#{ft}" do
        assert_instance_of HTS::Bam::Header, bam(ft).header
      end

      define_method "test_file_format_#{ft}" do
        assert_equal format, bam(ft).file_format
      end

      define_method "test_file_format_version_#{ft}" do
        assert_includes ["1", "1.6", "3.0"], bam(ft).file_format_version
      end

      define_method "test_each_#{ft}_with_block" do
        c = 0
        bam(ft).all? do |r|
          c += 1
          r.is_a? HTS::Bam::Record
        end
        assert_equal 10, c
      end

      define_method "test_each_#{ft}_without_block" do
        e = bam(ft).each
        c = 0
        e.all? do |r|
          c += 1
          r.is_a? HTS::Bam::Record
        end
        assert_equal 10, c
      end

      define_method "test_qname_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, :qname)
        else
          act = bam(ft).qname
          exp = bam(ft).map(&:qname)
          assert_equal exp, act
        end
      end

      define_method "test_flag_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, nil) { |r| r.is_a?(HTS::Bam) ? r.flag.map(&:to_i) : r.flag.to_i }
        else
          act = bam(ft).flag.map(&:to_i)
          exp = bam(ft).map { |r| r.flag.to_i }
          assert_equal exp, act
        end
      end

      define_method "test_chrom_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, :chrom)
        else
          act = bam(ft).chrom
          exp = bam(ft).map(&:chrom)
          assert_equal exp, act
        end
      end

      define_method "test_pos_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, :pos)
        else
          act = bam(ft).pos
          exp = bam(ft).map(&:pos)
          assert_equal exp, act
        end
      end

      define_method "test_mapq_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, :mapq)
        else
          act = bam(ft).mapq
          exp = bam(ft).map(&:mapq)
          assert_equal exp, act
        end
      end

      define_method "test_cigar_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, nil) { |r| r.is_a?(HTS::Bam) ? r.cigar.map(&:to_s) : r.cigar.to_s }
        else
          act = bam(ft).cigar.map(&:to_s)
          exp = bam(ft).map { |r| r.cigar.to_s }
          assert_equal exp, act
        end
      end

      define_method "test_mate_chrom_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, :mate_chrom)
        else
          act = bam(ft).mate_chrom
          exp = bam(ft).map(&:mate_chrom)
          assert_equal exp, act
        end
      end

      define_method "test_mpos_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, :mpos)
        else
          act = bam(ft).mpos
          exp = bam(ft).map(&:mpos)
          assert_equal exp, act
        end
      end

      define_method "test_isize_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, :isize)
        else
          act = bam(ft).isize
          exp = bam(ft).map(&:isize)
          assert_equal exp, act
        end
      end

      define_method "test_seq_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, :seq)
        else
          act = bam(ft).seq
          exp = bam(ft).map(&:seq)
          assert_equal exp, act
        end
      end

      define_method "test_qual_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, :qual)
        else
          act = bam(ft).qual
          exp = bam(ft).map(&:qual)
          assert_equal exp, act
        end
      end

      define_method "test_aux_#{ft}" do
        if format == "cram"
          assert_cram_getter_equal(ft, nil) { |r| r.is_a?(HTS::Bam) ? r.aux("MC") : r.aux("MC") }
        else
          act = bam(ft).aux("MC")
          exp = bam(ft).map { |r| r.aux("MC") }
          assert_equal exp, act
        end
      end

      next unless format != "sam"

      define_method "test_query_#{ft}" do
        arr = []
        bam(ft).query("chr2:350-700") do |aln|
          arr << aln.pos
        end
        assert_equal [341, 658], arr
      end

      define_method "test_query_copy_#{ft}" do
        arr = []
        bam(ft).query("chr2:350-700", copy: true) do |aln|
          arr << aln.pos
        end
        assert_equal [341, 658], arr
      end

      define_method "test_query3_#{ft}" do
        arr = []
        bam(ft).query("chr2", 350, 700) do |aln|
          arr << aln.pos
        end
        assert_equal [341, 658], arr
      end

      define_method "test_query3_copy_#{ft}" do
        arr = []
        bam(ft).query("chr2", 350, 700, copy: true) do |aln|
          arr << aln.pos
        end
        assert_equal [341, 658], arr
      end

      define_method "test_query3_without_block_#{ft}" do
        assert_equal [341, 658], bam(ft).query("chr2", 350, 700).map(&:pos)
      end
    end
  end

  # CRAM multi-region iterator has issues, only test BAM formats
  %i[bam_string bam_uri].each do |ft|
    define_method "test_query_multi_regions_#{ft}" do
      arr = []
      bam(ft).query(["chr1:100-200", "chr2:350-700"]) do |aln|
        arr << aln.pos
      end
      # Should get records from both regions
      assert_includes arr, 341
      assert_includes arr, 658
    end

    define_method "test_query_multi_regions_copy_#{ft}" do
      arr = []
      bam(ft).query(["chr1:100-200", "chr2:350-700"], copy: true) do |aln|
        arr << aln.pos
      end
      # Should get records from both regions
      assert_includes arr, 341
      assert_includes arr, 658
    end

    define_method "test_query_multi_regions_single_#{ft}" do
      # Single region as array should also work
      arr = []
      bam(ft).query(["chr2:350-700"]) do |aln|
        arr << aln.pos
      end
      assert_equal [341, 658], arr
    end
  end

  def test_initialize_no_file_bam
    silence_stderr do
      assert_raises(Errno::ENOENT) { HTS::Bam.new("/tmp/no_such_file") }
    end
  end

  def test_index_loading_is_lazy
    bam = HTS::Bam.new(path_bam_string)

    refute bam.index_loaded?
    assert_instance_of HTS::Bam::Record, bam.first
    refute bam.index_loaded?
    assert_instance_of HTS::Bam::Record, bam.query("chr2:350-700").first
    assert bam.index_loaded?
  ensure
    bam&.close
  end

  def test_explicit_index_is_loaded_eagerly
    bam = HTS::Bam.new(path_bam_string, index: "#{path_bam_string}.bai")

    assert bam.index_loaded?
  ensure
    bam&.close
  end

  def test_build_index
    Dir.mktmpdir do |dir|
      index_path = File.join(dir, "moo.bam.bai")

      bam("bam_string").build_index(index_path, verbose: false)

      assert_equal true, File.exist?(index_path)
    end
  end

  def test_class_build_index_with_explicit_index_name
    Dir.mktmpdir do |dir|
      bam_path = File.join(dir, "copy.bam")
      index_path = File.join(dir, "copy.bam.bai")
      FileUtils.cp(path_bam_string, bam_path)

      HTS::Bam.build_index(bam_path, index_path, 0, 0, false)

      assert_equal true, File.exist?(index_path)
    end
  end

  def test_class_build_index_with_default_index_name
    Dir.mktmpdir do |dir|
      bam_path = File.join(dir, "copy.bam")
      default_index_path = "#{bam_path}.bai"
      FileUtils.cp(path_bam_string, bam_path)

      HTS::Bam.build_index(bam_path, nil, 0, 0, false)

      assert_equal true, File.exist?(default_index_path)
    end
  end

  # Tag writing tests
  def test_aux_update_int
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    # Update existing tag
    aux.update_int("AS", 42)
    assert_equal 42, aux.get_int("AS")

    # Add new tag
    aux.update_int("NM", 5)
    assert_equal 5, aux.get_int("NM")

    bam.close
  end

  def test_aux_update_rejects_non_ascii_or_non_two_byte_tags
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    assert_raises(ArgumentError) { aux.update_int("A", 1) }
    assert_raises(ArgumentError) { aux.update_int("ABC", 1) }
    assert_raises(ArgumentError) { aux.update_int("éA", 1) }
    assert_raises(ArgumentError) { aux.update_int("é", 1) }

    bam.close
  end

  def test_aux_update_float
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    # Add float tag
    aux.update_float("ZF", 3.14)
    assert_in_delta 3.14, aux.get_float("ZF"), 0.001

    bam.close
  end

  def test_aux_update_string
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    # Update existing string tag
    aux.update_string("MC", "100M")
    assert_equal "100M", aux.get_string("MC")

    # Add new string tag
    aux.update_string("RG", "sample1")
    assert_equal "sample1", aux.get_string("RG")

    bam.close
  end

  def test_aux_update_string_validation
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    assert_equal "with space", aux.update_string("ZS", "with space")
    assert_equal "", aux.update_string("ZE", "")
    assert_equal "café", aux.update_string("ZU", "café")
    assert_equal "with\ttab", aux.update_string("ZT", "with\ttab")
    assert_raises(ArgumentError) { aux.update_string("ZS", "abc\0def") }

    bam.close
  end

  def test_aux_update_char
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    aux.update_char("YC", "N")
    assert_equal "N", aux["YC"]

    bam.close
  end

  def test_aux_update_char_validation
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    assert_raises(ArgumentError) { aux.update_char("YC", "") }
    assert_raises(ArgumentError) { aux.update_char("YC", "AB") }
    assert_raises(ArgumentError) { aux.update_char("YC", "\0") }
    assert_raises(ArgumentError) { aux.update_char("YC", "é") }

    bam.close
  end

  def test_aux_update_hex
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    aux.update_hex("YH", "DEADBEEF")
    assert_equal "DEADBEEF", aux["YH"]

    bam.close
  end

  def test_aux_update_double
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    aux.update_double("YD", 6.25)
    assert_in_delta 6.25, aux["YD"], 0.0001

    bam.close
  end

  def test_aux_update_typed_integers
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    aux.update_int8("A1", -5)
    aux.update_uint8("A2", 250)
    aux.update_int16("A3", -1024)
    aux.update_uint16("A4", 60_000)
    aux.update_int32("A5", -1_000_000)
    aux.update_uint32("A6", 4_000_000_000)

    assert_equal(-5, aux["A1"])
    assert_equal(250, aux["A2"])
    assert_equal(-1024, aux["A3"])
    assert_equal(60_000, aux["A4"])
    assert_equal(-1_000_000, aux["A5"])
    assert_equal(4_000_000_000, aux["A6"])

    bam.close
  end

  def test_aux_update_array_int
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    # Add integer array
    aux.update_array("ZI", [1, 2, 3, 4, 5])
    result = aux["ZI"]
    assert_equal [1, 2, 3, 4, 5], result

    bam.close
  end

  def test_aux_update_array_float
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    # Add float array
    aux.update_array("ZF", [1.1, 2.2, 3.3])
    result = aux["ZF"]
    assert_equal 3, result.size
    assert_in_delta 1.1, result[0], 0.001
    assert_in_delta 2.2, result[1], 0.001
    assert_in_delta 3.3, result[2], 0.001

    bam.close
  end

  def test_aux_update_array_with_uint8_subtype
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    aux.update_array("ZC", [1, 2, 255], type: "C")
    assert_equal [1, 2, 255], aux["ZC"]

    bam.close
  end

  def test_aux_update_hex_validation
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    assert_raises(ArgumentError) { aux.update_hex("YH", "ABC") }
    assert_raises(ArgumentError) { aux.update_hex("YH", "GG") }
    assert_raises(ArgumentError) { aux.update_hex("YH", "DE\0A") }
    assert_raises(ArgumentError) { aux.update_hex("YH", "éA") }

    bam.close
  end

  def test_aux_bracket_assignment
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    # Test []= with different types
    aux["AS"] = 100
    assert_equal 100, aux["AS"]

    aux["ZF"] = 2.718
    assert_in_delta 2.718, aux["ZF"], 0.001

    aux["ZS"] = "test_string"
    assert_equal "test_string", aux["ZS"]

    aux["ZA"] = [10, 20, 30]
    assert_equal [10, 20, 30], aux["ZA"]

    bam.close
  end

  def test_aux_delete
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    # Add a tag and delete it
    aux["ZZ"] = 999
    assert_equal 999, aux["ZZ"]
    assert aux.key?("ZZ")

    result = aux.delete("ZZ")
    assert result
    assert_nil aux["ZZ"]
    refute aux.key?("ZZ")

    # Deleting non-existent tag returns false
    result = aux.delete("XX")
    refute result

    bam.close
  end

  def test_aux_key?
    bam = HTS::Bam.new(path_bam_string)
    record = bam.first
    aux = record.aux

    # Existing tag (AS exists in first record)
    assert aux.key?("AS")
    assert aux.include?("AS")

    # Non-existent tag
    refute aux.key?("ZZ")
    refute aux.include?("ZZ")

    # After adding
    aux["ZZ"] = 123
    assert aux.key?("ZZ")

    bam.close
  end

  def test_aux_roundtrip_write_read
    require "tempfile"

    # Create a temporary BAM file
    Tempfile.create(["test_bam_write", ".bam"]) do |tmp|
      tmp_path = tmp.path
      tmp.close

      # Read original BAM
      input_bam = HTS::Bam.new(path_bam_string)
      header = input_bam.header

      # Write BAM with modified tags
      output_bam = HTS::Bam.new(tmp_path, "wb")
      output_bam.write_header(header)

      input_bam.each do |record|
        aux = record.aux
        aux["AS"] = 999
        aux["ZT"] = "modified"
        aux["ZA"] = [1, 2, 3]
        output_bam.write(record)
      end

      input_bam.close
      output_bam.close

      # Read back and verify
      verify_bam = HTS::Bam.new(tmp_path)
      verify_bam.each do |record|
        assert_equal 999, record.aux["AS"]
        assert_equal "modified", record.aux["ZT"]
        assert_equal [1, 2, 3], record.aux["ZA"]
      end
      verify_bam.close
    end
  end
end
