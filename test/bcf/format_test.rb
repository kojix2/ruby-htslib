# frozen_string_literal: true

require "tempfile"
require_relative "../test_helper"

class BcfFormatTest < Minitest::Test
  def test_bcf_path
    File.expand_path("../../htslib/test/tabix/vcf_file.bcf", __dir__)
  end

  def setup
    @bcf = HTS::Bcf.new(test_bcf_path)
    rec2 = @bcf.take(3).last
    @fmt = rec2.format
  end

  def teardown
    @bcf.close
  end

  def with_temp_character_format_vcf
    Tempfile.create(["format_character", ".vcf"]) do |file|
      file.write <<~VCF
        ##fileformat=VCFv4.3
        ##contig=<ID=1,length=100>
        ##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
        ##FORMAT=<ID=ST,Number=1,Type=String,Description="String field">
        ##FORMAT=<ID=CH,Number=1,Type=Character,Description="Character field">
        ##FORMAT=<ID=MISS,Number=1,Type=String,Description="defined but absent">
        #CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tS1\tS2
        1\t10\t.\tA\tC\t.\tPASS\t.\tGT:ST:CH\t0/1:ALPHA:A\t1/1:BETA:Z
      VCF
      file.flush

      yield file.path
    end
  end

  def with_temp_bcf
    Tempfile.create(["format_test", ".bcf"]) do |file|
      path = file.path
      file.close

      header = HTS::Bcf::Header.new
      header.set_version("VCFv4.3")
      header.append("##contig=<ID=1,length=100>")
      header.append('##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">')
      header.append('##FORMAT=<ID=PL,Number=G,Type=Integer,Description="Phred likelihoods">')
      header.append('##FORMAT=<ID=MISSI,Number=1,Type=Integer,Description="defined but absent integer">')
      header.append('##FORMAT=<ID=MISSF,Number=1,Type=Float,Description="defined but absent float">')
      header.append('##FORMAT=<ID=IV,Number=.,Type=Integer,Description="integer with sentinels">')
      header.append('##FORMAT=<ID=FV,Number=.,Type=Float,Description="float with sentinels">')
      header.add_sample("S1", sync: false)
      header.add_sample("S2", sync: true)

      HTS::Bcf.open(path, "wb") do |bcf|
        bcf.write_header(header)

        record = HTS::Bcf::Record.new(header)
        record.rid = header.name2id("1")
        record.pos = 9
        record.alleles = %w[A C]

        genotypes = [
          HTS::Bcf::Format.gt_unphased(0),
          HTS::Bcf::Format.gt_unphased(1),
          HTS::Bcf::Format.gt_unphased(1),
          HTS::Bcf::Format.gt_unphased(1)
        ]
        record.format.update_genotypes(genotypes)

        likelihoods = [10, 20, 30, 40, 50, 60]
        record.format.update_int("PL", likelihoods)

        int_with_sentinels = [10, HTS::Native::BCF_INT32_VECTOR_END,
                              HTS::Native::BCF_INT32_MISSING, HTS::Native::BCF_INT32_VECTOR_END]
        record.format.update_int("IV", int_with_sentinels)

        float_words = [0x3fc0_0000, 0x7f80_0002, 0x7f80_0001, 0x7f80_0002]
        record.format.update_float_words("FV", float_words)

        bcf.write(record)
      end

      yield path
    end
  end

  def with_temp_gt_vcf
    Tempfile.create(["format_gt", ".vcf"]) do |file|
      file.write <<~VCF
        ##fileformat=VCFv4.3
        ##contig=<ID=1,length=100>
        ##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
        #CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tS1\tS2\tS3\tS4
        1\t10\t.\tA\tC\t.\tPASS\t.\tGT\t0|1\t0/1\t./.\t1
      VCF
      file.flush

      yield file.path
    end
  end

  def with_temp_flag_format_vcf
    Tempfile.create(["format_flag", ".vcf"]) do |file|
      file.write <<~VCF
        ##fileformat=VCFv4.3
        ##contig=<ID=1,length=100>
        ##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
        ##FORMAT=<ID=BAD,Number=0,Type=Flag,Description="Unsupported">
        #CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tS1
        1\t10\t.\tA\tC\t.\tPASS\t.\tGT\t0/1
      VCF
      file.flush

      yield file.path
    end
  end

  def with_temp_format_source_vcf
    Tempfile.create(["format_source", ".vcf"]) do |file|
      file.write <<~VCF
        ##fileformat=VCFv4.3
        ##contig=<ID=1,length=100>
        ##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
        ##FORMAT=<ID=GQ,Number=1,Type=Integer,Description="Genotype quality">
        ##FORMAT=<ID=TF,Number=1,Type=Float,Description="Float field">
        ##FORMAT=<ID=ST,Number=1,Type=String,Description="String field">
        ##FORMAT=<ID=MISSI,Number=1,Type=Integer,Description="Defined but absent integer">
        #CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tS1\tS2
        1\t10\t.\tA\tC\t.\tPASS\t.\tGT:GQ:TF:ST\t0/1:10:1.5:ALPHA\t1/1:20:2.5:BETA
      VCF
      file.flush

      yield file.path
    end
  end

  def with_temp_output_path(ext = ".vcf")
    Tempfile.create(["format_output", ext]) do |file|
      path = file.path
      file.close
      yield path
    end
  end

  def test_get_with_type
    assert_equal [409, 409], @fmt.get("GQ", :int)
    assert_equal [35, 35], @fmt.get("DP", :int)
    assert_equal [-20.0, -5.0, -20.0, -20.0, -5.0, -20.0], @fmt.get("GL", :float)
    assert_equal ["0/1", "0/1"], @fmt.get("GT", :string)
  end

  def test_get_like_crystal
    assert_equal [409, 409], @fmt.get_int("GQ")
    assert_equal [35, 35], @fmt.get_int("DP")
    assert_equal [-20.0, -5.0, -20.0, -20.0, -5.0, -20.0], @fmt.get_float("GL")
    assert_equal ["0/1", "0/1"], @fmt.get_string("GT")
    assert_equal [2, 4, 2, 4], @fmt.get_genotypes
  end

  def test_get_without_type
    assert_equal [409, 409], @fmt.get("GQ")
    assert_equal [35, 35], @fmt.get("DP")
    assert_equal [[-20.0, -5.0, -20.0], [-20.0, -5.0, -20.0]], @fmt.get("GL")
    assert_equal ["0/1", "0/1"], @fmt.get("GT")
  end

  def test_get_square_brackets
    assert_equal [409, 409], @fmt["GQ"]
    assert_equal [35, 35], @fmt["DP"]
    assert_equal [[-20.0, -5.0, -20.0], [-20.0, -5.0, -20.0]], @fmt["GL"]
    assert_equal ["0/1", "0/1"], @fmt["GT"]
  end

  def test_get_unknown_key
    assert_nil @fmt.get("UN")
    assert_nil @fmt.get_string("UNKNOWN")
    assert_nil @fmt["UNKNOWN"]
    assert_nil @fmt["UN"]
  end

  def test_character_format_is_routed_through_string
    with_temp_character_format_vcf do |path|
      HTS::Bcf.open(path) do |bcf|
        format = bcf.first.format

        assert_equal %w[ALPHA BETA], format.get_string("ST")
        assert_equal %w[A Z], format.get_string("CH")
        assert_nil format.get_string("MISS")
      end
    end
  end

  def test_gt_decoding_handles_phased_missing_and_lower_ploidy
    with_temp_gt_vcf do |path|
      HTS::Bcf.open(path) do |bcf|
        format = bcf.first.format
        raw = format.get_genotypes

        assert_equal 8, raw.size
        assert_equal 0, HTS::Bcf::Format.gt_allele(raw[0])
        assert_equal 1, HTS::Bcf::Format.gt_allele(raw[1])
        assert HTS::Bcf::Format.gt_phased?(raw[1])
        assert HTS::Bcf::Format.gt_missing?(raw[4])
        assert HTS::Bcf::Format.gt_missing?(raw[5])
        assert_equal 1, HTS::Bcf::Format.gt_allele(raw[6])
        assert HTS::Bcf::Format.gt_vector_end?(raw[7])
        assert_equal ["0|1", "0/1", "./.", "1"], format.get_string("GT")
      end
    end
  end

  def test_genotype_view_ignores_phase_bit_on_first_allele
    buffer = HTS::Bcf::Format::BufferState.new(1)
    values = [HTS::Bcf::Format.gt_phased(0), HTS::Bcf::Format.gt_phased(1)]
    view = HTS::Bcf::Format::GenotypeView.new.reset(values, buffer, 1)

    assert_equal [[0, false, false], [1, true, false]], view.each_allele.to_a
    assert_equal "0|1", view.to_s
  end

  def test_low_level_contract
    assert_nil @fmt.get_int("NO_SUCH_TAG")
    assert_nil @fmt.get_float("NO_SUCH_TAG")
    assert_nil @fmt.get_string("NO_SUCH_TAG")

    ex = assert_raises(HTS::Bcf::FormatTypeError) { @fmt.get_float("GQ") }
    assert_equal "Tag GQ is not float FORMAT field", ex.message
  end

  def test_format_flag_is_unsupported
    with_temp_flag_format_vcf do |path|
      HTS::Bcf.open(path) do |bcf|
        format = bcf.first.format

        ex = assert_raises(HTS::Bcf::UnsupportedFormatOperationError) { format.get_string("BAD") }
        assert_equal "FORMAT flag fields are not supported: BAD", ex.message
      end
    end
  end

  def test_fields
    assert_equal [{ name: "GT", n: 1, type: :string, id: 4 },
                  { name: "GQ", n: 1, type: :int, id: 5 },
                  { name: "DP", n: 1, type: :int, id: 6 },
                  { name: "GL", n: 1_048_575, type: :float, id: 7 }],
                 @fmt.fields
  end

  def test_to_h
    assert_equal(
      { "GT" => ["0/1", "0/1"], "GQ" => [409, 409], "DP" => [35, 35],
        "GL" => [[-20.0, -5.0, -20.0], [-20.0, -5.0, -20.0]] },
      @fmt.to_h
    )
  end

  def test_get_high_level_shapes_values_by_sample
    with_temp_bcf do |path|
      HTS::Bcf.open(path) do |bcf|
        format = bcf.first.format

        assert_equal ["0/1", "1/1"], format.get("GT")
        assert_equal [[10, 20, 30], [40, 50, 60]], format.get("PL")
        assert_equal [[10], [nil]], format.get("IV")

        floats = format.get("FV")
        assert_equal 2, floats.size
        assert_equal [1.5], floats[0]
        assert_equal [nil], floats[1]
        assert_nil format.get("MISSI")
        assert_nil format.get("MISSF")
      end
    end
  end

  def test_get_raw_preserves_flat_numeric_buffers
    with_temp_bcf do |path|
      HTS::Bcf.open(path) do |bcf|
        format = bcf.first.format

        assert_equal [10, 20, 30, 40, 50, 60], format.get_raw("PL")

        ints = format.get_raw("IV")
        assert_equal 4, ints.size
        assert_equal 10, ints[0]
        assert_equal HTS::Native::BCF_INT32_VECTOR_END, ints[1]
        assert_equal HTS::Native::BCF_INT32_MISSING, ints[2]
        assert_equal HTS::Native::BCF_INT32_VECTOR_END, ints[3]

        floats = format.get_raw("FV")
        assert_equal 4, floats.size
        assert_equal 0x3fc0_0000, floats[0]
        assert_equal HTS::Native::BCF_FLOAT_VECTOR_END, floats[1]
        assert_equal HTS::Native::BCF_FLOAT_MISSING, floats[2]
        assert_equal HTS::Native::BCF_FLOAT_VECTOR_END, floats[3]

        decoded_floats = format.get_float("FV")
        assert_in_delta 1.5, decoded_floats[0], 0.001
        assert_nil decoded_floats[1]
        assert_nil decoded_floats[2]
        assert_nil decoded_floats[3]
      end
    end
  end

  def test_update_methods_round_trip
    with_temp_format_source_vcf do |source_path|
      with_temp_output_path do |output_path|
        input_bcf = HTS::Bcf.new(source_path)
        record = input_bcf.first
        format = record.format

        format.update_int("GQ", [11, 22])
        format.update_float("TF", [1.25, 2.75])
        format.update_string("ST", %w[LEFT RIGHT])
        format.update_genotypes([
                                  HTS::Bcf::Format.gt_unphased(0),
                                  HTS::Bcf::Format.gt_unphased(0),
                                  HTS::Bcf::Format.gt_phased(1),
                                  HTS::Bcf::Format.gt_phased(1)
                                ])

        HTS::Bcf.open(output_path, "w") do |output_bcf|
          output_bcf.write_header(input_bcf.header)
          output_bcf.write(record)
        end
        input_bcf.close

        HTS::Bcf.open(output_path) do |verify_bcf|
          verify_format = verify_bcf.first.format

          assert_equal [11, 22], verify_format.get_int("GQ")
          assert_equal %w[LEFT RIGHT], verify_format.get_string("ST")
          assert_equal ["0/0", "1|1"], verify_format.get_string("GT")

          floats = verify_format.get_float("TF")
          assert_equal 2, floats.size
          assert_in_delta 1.25, floats[0], 0.001
          assert_in_delta 2.75, floats[1], 0.001
        end
      end
    end
  end

  def test_delete_round_trip
    with_temp_format_source_vcf do |source_path|
      with_temp_output_path do |output_path|
        input_bcf = HTS::Bcf.new(source_path)
        record = input_bcf.first
        format = record.format

        assert_equal true, format.delete("ST")
        assert_equal false, format.delete("ST")

        HTS::Bcf.open(output_path, "w") do |output_bcf|
          output_bcf.write_header(input_bcf.header)
          output_bcf.write(record)
        end
        input_bcf.close

        HTS::Bcf.open(output_path) do |verify_bcf|
          verify_format = verify_bcf.first.format
          assert_nil verify_format.get_string("ST")
        end
      end
    end
  end

  def test_update_unknown_tag
    with_temp_format_source_vcf do |source_path|
      HTS::Bcf.open(source_path) do |bcf|
        format = bcf.first.format

        ex = assert_raises(HTS::Bcf::FormatDefinitionError) { format.update_int("NOPE", [1, 2]) }
        assert_equal "FORMAT tag NOPE not defined in header", ex.message
      end
    end
  end

  def test_update_values_not_divisible_by_samples
    with_temp_format_source_vcf do |source_path|
      HTS::Bcf.open(source_path) do |bcf|
        format = bcf.first.format

        ex = assert_raises(ArgumentError) { format.update_int("GQ", [1, 2, 3]) }
        assert_equal "FORMAT values for GQ must be divisible by sample count (2)", ex.message
      end
    end
  end

  def test_update_string_requires_one_value_per_sample
    with_temp_format_source_vcf do |source_path|
      HTS::Bcf.open(source_path) do |bcf|
        format = bcf.first.format

        ex = assert_raises(ArgumentError) { format.update_string("ST", "solo") }
        assert_equal "FORMAT string values for ST must provide one entry per sample (2)", ex.message
      end
    end
  end
end
