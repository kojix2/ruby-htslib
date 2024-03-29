# frozen_string_literal: true

require_relative "../test_helper"

class BamFlagTest < Minitest::Test
  def setup
    @flag = HTS::Bam::Flag.new(4095)
    @flag_zero = HTS::Bam::Flag.new(0)
  end

  # BAM_FPAIRED        =    1
  # BAM_FPROPER_PAIR   =    2
  # BAM_FUNMAP         =    4
  # BAM_FMUNMAP        =    8
  # BAM_FREVERSE       =   16
  # BAM_FMREVERSE      =   32
  # BAM_FREAD1         =   64
  # BAM_FREAD2         =  128
  # BAM_FSECONDARY     =  256
  # BAM_FQCFAIL        =  512
  # BAM_FDUP           = 1024
  # BAM_FSUPPLEMENTARY = 2048

  def test_value
    assert_equal 4095, @flag.value
    assert_equal 0, @flag_zero.value
  end

  FLAG_METHODS = %w[
    paired?
    proper_pair?
    unmapped?
    mate_unmapped?
    reverse?
    mate_reverse?
    read1?
    read2?
    secondary?
    qcfail?
    duplicate?
    supplementary?
  ].freeze

  FLAG_METHODS.each do |flag_name|
    define_method("test_#{flag_name}") do
      assert_equal true, @flag.public_send(flag_name)
      assert_equal false, @flag_zero.public_send(flag_name)
    end
  end

  def test_bitwise_and
    assert_equal 1024, (@flag & 1024).value
    assert_equal 0, (@flag_zero & 1024).value
  end

  def test_bitwise_or
    assert_equal 4095, (@flag | 1024).value
    assert_equal 1024, (@flag_zero | 1024).value
  end

  def test_bitwize_xor
    assert_equal 3071, (@flag ^ 1024).value
    assert_equal 1024, (@flag_zero ^ 1024).value
  end

  def test_bitwise_not
    assert_equal(-4096, (~@flag).value)
    assert_equal(-1, (~@flag_zero).value)
  end

  def test_bitwise_shift_left
    assert_equal 8190, (@flag << 1).value
    assert_equal 0, (@flag_zero << 1).value
  end

  def test_bitwise_shift_right
    assert_equal 2047, (@flag >> 1).value
    assert_equal 0, (@flag_zero >> 1).value
  end

  def test_to_i
    assert_equal 4095, @flag.to_i
    assert_equal 0, @flag_zero.to_i
  end

  def test_to_s
    assert_equal "PAIRED,PROPER_PAIR,UNMAP,MUNMAP,REVERSE,MREVERSE,READ1,READ2,SECONDARY,QCFAIL,DUP,SUPPLEMENTARY",
                 @flag.to_s
    assert_equal "", @flag_zero.to_s
  end
end
