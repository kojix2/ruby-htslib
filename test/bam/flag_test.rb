# frozen_string_literal: true

require_relative "../test_helper"

class FlagTest < Minitest::Test
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

  Flags = %w[
    paired
    proper_pair
    unmap
    munmap
    reverse
    mreverse
    read1
    read2
    secondary
    qcfail
    dup
    supplementary
  ].freeze

  def test_value
    assert_equal 4095, @flag.value
    assert_equal 0, @flag_zero.value
  end

  Flags.each do |flag|
    define_method "test_#{flag}?" do
      assert_equal true, @flag.paired?
      assert_equal false, @flag_zero.paired?
    end
  end

  def test_paired?
    assert_equal true, @flag.paired?
    assert_equal false, @flag_zero.paired?
  end
end
