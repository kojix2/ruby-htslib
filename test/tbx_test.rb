# frozen_string_literal: true

require_relative "test_helper"

class TbxTest < Minitest::Test
  def setup
    @bcf = HTS::Tbx.new(Fixtures["test.vcf.gz"])
  end

  def test_initialize
    assert_instance_of HTS::Tbx, @bcf
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

  def test_tid
    assert_equal 0, @bcf.tid("poo")
  end

  def test_seqnames
    assert_equal ["poo"], @bcf.seqnames
  end

  def test_query
    assert_equal "poo\t4021\t.\tG\tT\t50.3961\t.\tDP=23;VDB=0.00423321;SGB=-0.680642;RPBZ=-1.75579;MQBZ=0;MQSBZ=0;BQBZ=0;SCBZ=0;FS=0;MQ0F=0;AC=1;AN=2;DP4=5,6,6,6;MQ=60\tGT:PL\t0/1:83,0,77",
                 @bcf.query("poo:4020-4022").first
  end
end
