# frozen_string_literal: true

require_relative "test_helper"

class TabixTest < Minitest::Test
  def setup
    @bcf = HTS::Tabix.new(Fixtures["test.vcf.gz"])
  end

  def teardown
    @bcf.close
  end

  def test_initialize
    assert_instance_of HTS::Tabix, @bcf
  end

  def test_native_handle_is_not_public
    refute_respond_to @bcf, :struct
    refute_respond_to @bcf, :to_ptr
  end

  def test_file_name
    assert_equal Fixtures["test.vcf.gz"], @bcf.file_name
  end

  def test_file_format
    assert_equal "vcf", @bcf.file_format
  end

  def test_close
    assert_equal false, @bcf.closed?
    @bcf.close
    assert_equal true, @bcf.closed?
    # second close should be no-op
    assert_nil @bcf.close
  end

  def test_name2id
    assert_equal 0, @bcf.name2id("poo")
  end

  def test_seqnames
    assert_equal ["poo"], @bcf.seqnames
  end

  def test_query
    itr = @bcf.query("poo:4020-4022")
    assert_equal [
      "poo", "4021", ".", "G", "T", "50.3961", ".",
      "DP=23;VDB=0.00423321;SGB=-0.680642;RPBZ=-1.75579;MQBZ=0;MQSBZ=0;BQBZ=0;SCBZ=0;FS=0;MQ0F=0;AC=1;AN=2;DP4=5,6,6,6;MQ=60",
      "GT:PL", "0/1:83,0,77"
    ], itr.next
    assert_raises(StopIteration) { itr.next }
    @bcf.query("poo:4020-4022") do |r|
      assert_equal [
        "poo", "4021", ".", "G", "T", "50.3961", ".",
        "DP=23;VDB=0.00423321;SGB=-0.680642;RPBZ=-1.75579;MQBZ=0;MQSBZ=0;BQBZ=0;SCBZ=0;FS=0;MQ0F=0;AC=1;AN=2;DP4=5,6,6,6;MQ=60",
        "GT:PL", "0/1:83,0,77"
      ], r
    end
    itr = @bcf.query("poo", 4020, 4022)
    assert_equal [
      "poo", "4021", ".", "G", "T", "50.3961", ".",
      "DP=23;VDB=0.00423321;SGB=-0.680642;RPBZ=-1.75579;MQBZ=0;MQSBZ=0;BQBZ=0;SCBZ=0;FS=0;MQ0F=0;AC=1;AN=2;DP4=5,6,6,6;MQ=60",
      "GT:PL", "0/1:83,0,77"
    ], itr.next
    assert_raises(StopIteration) { itr.next }
    @bcf.query("poo", 4020, 4022) do |r|
      assert_equal [
        "poo", "4021", ".", "G", "T", "50.3961", ".",
        "DP=23;VDB=0.00423321;SGB=-0.680642;RPBZ=-1.75579;MQBZ=0;MQSBZ=0;BQBZ=0;SCBZ=0;FS=0;MQ0F=0;AC=1;AN=2;DP4=5,6,6,6;MQ=60",
        "GT:PL", "0/1:83,0,77"
      ], r
    end
  end

  def test_each_line
    line = @bcf.each_line("poo:4020-4022").first

    assert_instance_of String, line
    assert_equal @bcf.query("poo:4020-4022").first, line.split("\t")
  end

  def test_each_fields
    assert_equal @bcf.query("poo:4020-4022").first,
                 @bcf.each_fields("poo:4020-4022").first
  end

  def test_each_selected_fields
    assert_equal ["poo", "4021", "G", "0/1:83,0,77"],
                 @bcf.each_selected_fields("poo:4020-4022", 0, 1, 3, 9).first
    assert_equal %w[G poo G],
                 @bcf.each_selected_fields("poo:4020-4022", 3, 0, 3).first
  end

  def test_start_and_end_must_be_provided_together
    assert_raises(ArgumentError) { @bcf.query("poo", 4020).first }
    assert_raises(ArgumentError) { @bcf.each_fields("poo", nil, 4022).first }
    assert_raises(ArgumentError) { @bcf.each_line("poo", 4020).first }
  end
end
