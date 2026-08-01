# frozen_string_literal: true

require "tempfile"
require_relative "test_helper"

class PerformancePlanTest < Minitest::Test
  def with_streaming_vcf
    Tempfile.create(["performance_plan", ".vcf"]) do |file|
      file.write <<~VCF
        ##fileformat=VCFv4.3
        ##contig=<ID=1,length=100>
        ##INFO=<ID=IV,Number=.,Type=Integer,Description="Integer vector">
        ##INFO=<ID=FL,Number=0,Type=Flag,Description="Flag">
        ##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
        ##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Depth">
        ##FORMAT=<ID=AD,Number=R,Type=Integer,Description="Allele depths">
        ##FORMAT=<ID=GL,Number=G,Type=Float,Description="Likelihoods">
        #CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tS1\tS2
        1\t10\t.\tA\tC\t.\tPASS\tIV=1,2,3,4;FL\tGT:DP:AD:GL\t0|1:10:4,6:-2.0,-1.0,-3.0\t1/1:20:0,20:-4.0,-2.0,-1.0
        1\t20\t.\tG\tT\t.\tPASS\tIV=9\tGT:DP:AD:GL\t0/0:5:5,0:-1.0,-2.0,-3.0\t0/1:7:3,4:-2.0,-1.0,-3.0
      VCF
      file.flush
      yield file.path
    end
  end

  def test_info_uses_returned_count_with_a_reused_buffer
    with_streaming_vcf do |path|
      values = []
      accessor_ids = []
      HTS::Bcf.open(path) do |bcf|
        bcf.each do |record|
          accessor_ids << record.info.object_id
          values << record.info.get("IV")
        end
      end

      assert_equal [[1, 2, 3, 4], [9]], values
      assert_equal 1, accessor_ids.uniq.length
    end
  end

  def test_info_missing_and_flag_fields
    with_streaming_vcf do |path|
      HTS::Bcf.open(path) do |bcf|
        first, second = bcf.each(copy: true).to_a
        assert_equal true, first.info.get("FL")
        assert_equal false, second.info.key?("FL")
        assert_nil second.info.get("FL")
        assert_nil second.info.get("UNKNOWN")
      end
    end
  end

  def test_format_streaming_apis
    with_streaming_vcf do |path|
      HTS::Bcf.open(path) do |bcf|
        format = bcf.first.format

        genotypes = []
        format.each_genotype do |sample_index, genotype|
          alleles = genotype.each_allele.to_a
          genotypes << [sample_index, genotype.to_s, alleles]
        end
        assert_equal [[0, "0|1", [[0, false, false], [1, true, false]]],
                      [1, "1/1", [[1, false, false], [1, false, false]]]], genotypes
        assert_equal "1/1", format.genotype_at("GT", 1).to_s
        assert_equal %w[0|1 1/1], format.genotype_strings

        assert_equal [[0, 10], [1, 20]], format.each_i32("DP").to_a
        assert_equal([[0, [4, 6]], [1, [0, 20]]],
                     format.each_i32_vector("AD").map { |sample, view| [sample, view.to_a] })

        floats = format.each_f32_vector("GL").map { |sample, view| [sample, view.to_a] }
        assert_equal [0, 1], floats.map(&:first)
        assert_equal [-2.0, -1.0, -3.0], floats[0][1]
        assert_equal [-4.0, -2.0, -1.0], floats[1][1]
      end
    end
  end

  def test_format_views_survive_getters_for_other_keys
    with_streaming_vcf do |path|
      HTS::Bcf.open(path) do |bcf|
        format = bcf.first.format
        observed = []

        format.each_genotype do |sample_index, genotype|
          depths = format.each_i32("DP").to_a
          observed << [sample_index, genotype.to_s, depths]
        end

        assert_equal [[0, "0|1", [[0, 10], [1, 20]]],
                      [1, "1/1", [[0, 10], [1, 20]]]], observed

        genotype = format.genotype_at("GT", 0)
        format.each_i32_vector("AD") { |_sample, values| values.each { |_value| } }
        assert_equal "0|1", genotype.to_s
      end
    end
  end

  def test_format_views_raise_after_their_buffer_is_reused
    with_streaming_vcf do |path|
      HTS::Bcf.open(path) do |bcf|
        format = bcf.first.format

        genotype = format.genotype_at("GT", 0)
        format.get_genotypes
        error = assert_raises(HTS::Bcf::InvalidBorrowedViewError) { genotype.to_s }
        assert_match(/no longer valid/, error.message)

        vector = format.each_i32_vector("AD").first.last
        format.get_raw("AD")
        assert_raises(HTS::Bcf::InvalidBorrowedViewError) { vector.to_a }
      end
    end
  end

  def test_record_accessors_are_memoized_but_not_shared_by_dup
    with_streaming_vcf do |path|
      HTS::Bcf.open(path) do |bcf|
        record = bcf.first
        assert_same record.info, record.info
        assert_same record.format, record.format

        copy = record.dup
        refute_same record.info, copy.info
        refute_same record.format, copy.format
      end
    end
  end

  def test_reader_sample_selection_and_unpack_level
    with_streaming_vcf do |path|
      HTS::Bcf.open(path, samples: ["S2"]) do |bcf|
        assert_equal ["S2"], bcf.samples
        assert_equal ["1/1"], bcf.first.format("GT")
      end

      HTS::Bcf.open(path, unpack: :site_only) do |bcf|
        record = bcf.first
        assert_equal [1, 2, 3, 4], record.info("IV")
        assert_nil record.format("DP")
      end
    end
  end

  def test_bam_primitive_iterators_and_direct_flags
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      record = bam.first
      assert_equal record.flag.value, record.flag_value
      assert_equal record.flag.unmapped?, record.unmapped?
      assert_equal record.qual, record.each_qual.to_a
      expected_quality = if record.qual.first == 255
                           "*"
                         else
                           record.qual.map { |quality| quality + 33 }.pack("C*")
                         end
      assert_equal expected_quality, record.qual_string
      assert_equal record.sequence.chars, record.each_base.to_a
      assert_equal record.len, record.each_base_code.count
      assert_equal(record.cigar.to_a,
                   record.each_cigar_raw.map { |op, length| [HTS::Bam::Cigar::OP_CHARS[op], length] })

      record.aux.update_array("XA", [-2, 0, 7], type: "i")
      assert_equal [-2, 0, 7], record.aux.get("XA")
      assert_equal [-2, 0, 7], record.aux.each_array("XA").to_a
    end
  end

  def test_materializing_apis_have_explicit_names
    with_streaming_vcf do |path|
      HTS::Bcf.open(path) do |bcf|
        assert_equal bcf.pos, bcf.pos_array
        records = bcf.collect_records
        assert_equal 2, records.length
        refute_same records[0], records[1]
        assert_equal [9], records[1].info("IV")
      end
    end

    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      assert_equal bam.pos, bam.pos_array
      records = bam.collect_records
      assert_operator records.length, :>, 1
      refute_same records[0], records[1]
      first_position = records[0].pos
      refute_nil records[1].pos
      assert_equal first_position, records[0].pos
    end
  end

  def test_native_bam_batch_filter
    HTS::Bam.open(Fixtures["moo.bam"]) do |bam|
      records = bam.collect_records

      expected = records.select do |record|
        record.mapq >= 40 && (record.flag_value & HTS::Bam::Flag::SECONDARY).zero?
      end
      actual = HTS::Bam.filter_records(
        records, min_mapq: 40, excluded_flags: HTS::Bam::Flag::SECONDARY
      )
      assert_equal expected, actual

      first = records.first
      expected = records.select do |record|
        record.tid == first.tid && record.endpos > first.pos && record.pos < first.endpos
      end
      actual = HTS::Bam.filter_records(
        records, tid: first.tid, beg: first.pos, end_: first.endpos
      )
      assert_equal expected, actual
    end
  end

  def test_native_bcf_batch_filter
    path = File.expand_path("../htslib/test/tabix/vcf_file.bcf", __dir__)
    HTS::Bcf.open(path) do |bcf|
      records = bcf.collect_records

      expected = records.select { |record| !record.qual.nan? && record.qual >= 50 }
      assert_equal expected, HTS::Bcf.filter_records(records, min_qual: 50)

      q10_record = records.find { |record| record.filter == "q10" }
      refute_nil q10_record
      q10_id = q10_record.each_filter_id.first
      expected = records.select { |record| record.filter_id?(q10_id) }
      assert_equal expected, HTS::Bcf.filter_records(records, filter_id: q10_id)

      first = records.first
      expected = records.select do |record|
        record.rid == first.rid && record.endpos > first.pos && record.pos < first.endpos
      end
      actual = HTS::Bcf.filter_records(
        records, rid: first.rid, beg: first.pos, end_: first.endpos
      )
      assert_equal expected, actual
    end
  end
end
