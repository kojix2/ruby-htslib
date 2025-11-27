# frozen_string_literal: true

require_relative "test_helper"

class HeaderTest < Minitest::Test
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
    assert_equal 0, result

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
    assert_equal 0, result

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
    assert_equal 0, result

    header_text = @header.to_s
    assert_match(/ID:custom_id/, header_text)
    assert_match(/PN:myprogram/, header_text)
  end

  def test_add_pg_empty_options
    result = @header.add_pg("simple_program")
    assert_equal 0, result

    header_text = @header.to_s
    assert_match(/@PG\t.*PN:simple_program/, header_text)
  end
end
