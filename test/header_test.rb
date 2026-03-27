# frozen_string_literal: true

require_relative "test_helper"

class HeaderTest < Minitest::Test
  MINIMAL_HEADER = <<~SAM.freeze
    @HD	VN:1.6	SO:coordinate
    @SQ	SN:chr1	LN:1000
  SAM

  RG_HEADER = <<~SAM.freeze
    @HD	VN:1.6	SO:coordinate
    @SQ	SN:chr1	LN:1000
    @RG	ID:rg1	SM:sample1
  SAM

  def setup
    @bam = HTS::Bam.open(Fixtures["poo.sort.bam"])
    @header = @bam.header
  end

  def teardown
    @bam&.close
  end

  def test_add_pg
    # Test basic @PG line addition
    result = @header.add_pg("test_program", VN: "1.0.0", CL: "test_program input.bam")
    assert_same @header, result

    # Check that the @PG line was added
    header_text = @header.to_s
    assert_match(/@PG\t.*PN:test_program/, header_text)
    assert_match(/VN:1.0.0/, header_text)
    assert_match(/CL:test_program input.bam/, header_text)
  end

  def test_add_pg_with_pp
    # Add first program
    @header.add_pg("program1", VN: "1.0")

    # Add second program with PP reference
    result = @header.add_pg("program2", VN: "2.0", PP: "program1")
    assert_same @header, result

    header_text = @header.to_s
    assert_match(/@PG\t.*PN:program1/, header_text)
    assert_match(/@PG\t.*PN:program2/, header_text)
    assert_match(/PP:program1/, header_text)
  end

  def test_add_pg_auto_id_generation
    # Add multiple programs with the same name
    # sam_hdr_add_pg should automatically generate unique IDs
    @header.add_pg("samtools")
    @header.add_pg("samtools")
    @header.add_pg("samtools")

    header_text = @header.to_s
    # Should have multiple @PG lines with samtools
    pg_lines = header_text.scan(/@PG\t.*PN:samtools/)
    assert_operator pg_lines.size, :>=, 3
  end

  def test_add_pg_with_id
    result = @header.add_pg("myprogram", ID: "custom_id", VN: "0.1")
    assert_same @header, result

    header_text = @header.to_s
    assert_match(/ID:custom_id/, header_text)
    assert_match(/PN:myprogram/, header_text)
  end

  def test_add_pg_empty_options
    result = @header.add_pg("simple_program")
    assert_same @header, result

    header_text = @header.to_s
    assert_match(/@PG\t.*PN:simple_program/, header_text)
  end

  def test_add_pg_rejects_duplicate_id
    @header.add_pg("align", ID: "existing_pg")

    error = assert_raises(ArgumentError) do
      @header.add_pg("sort", ID: "existing_pg")
    end
    assert_includes error.message, "PG ID already exists"
  end

  def test_add_pg_rejects_unknown_parent
    error = assert_raises(ArgumentError) do
      @header.add_pg("sort", PP: "missing")
    end
    assert_includes error.message, "Unknown PG parent"
  end

  def test_add_pg_rejects_tabs_and_newlines
    error = assert_raises(ArgumentError) do
      @header.add_pg("align", CL: "samtools\tview")
    end
    assert_includes error.message, "must not contain tabs or newlines"

    error = assert_raises(ArgumentError) do
      @header.add_pg("align", CL: "samtools\nview")
    end
    assert_includes error.message, "must not contain tabs or newlines"
  end

  def test_update_hd
    header = HTS::Bam::Header.parse(MINIMAL_HEADER)

    header.update_hd(version: "1.7", group_order: "query")

    assert_match(/@HD\tVN:1.7\tSO:coordinate\tGO:query/, header.to_s)
  end

  def test_add_update_remove_sq
    header = HTS::Bam::Header.parse(MINIMAL_HEADER)

    header.add_sq("chr2", length: 2000, assembly: "GRCh38")
    assert_equal 2, header.count_lines("SQ")
    assert_equal "chr2", header.line_name("SQ", 1)
    assert_equal "2000", header.find_tag("SQ", "SN", "chr2", "LN")

    header.update_sq("chr2", md5: "abc123")
    assert_equal "abc123", header.find_tag("SQ", "SN", "chr2", "M5")

    assert_equal true, header.remove_sq("chr2")
    assert_nil header.find_line("SQ", "SN", "chr2")
  end

  def test_add_update_remove_rg
    header = HTS::Bam::Header.parse(RG_HEADER)

    header.add_rg("rg2", sample: "sample2", platform: "ILLUMINA")
    assert_equal 2, header.count_lines("RG")
    assert_equal "sample2", header.find_tag("RG", "ID", "rg2", "SM")

    header.update_rg("rg2", description: "tumor")
    assert_equal "tumor", header.find_tag("RG", "ID", "rg2", "DS")

    assert_equal true, header.delete_tag("RG", "ID", "rg2", "DS")
    assert_nil header.find_tag("RG", "ID", "rg2", "DS")

    assert_equal true, header.remove_rg("rg2")
    assert_nil header.find_line("RG", "ID", "rg2")
  end
end
