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

  def test_struct
    assert_equal false, @bcf.struct.null?
  end

  def test_file_name
    assert_equal Fixtures["test.vcf.gz"], @bcf.file_name
  end

  def test_file_format
    assert_equal "vcf", @bcf.file_format
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
end
