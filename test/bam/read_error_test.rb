# frozen_string_literal: true

require_relative "../test_helper"

class BamReadErrorTest < Minitest::Test
  FakeNative = Struct.new(:results) do
    def read(*) = results.shift
    def closed? = false
  end

  def test_each_raises_on_native_read_error_without_yielding_invalid_record
    assert_read_error(copy: false)
  end

  def test_copying_each_raises_on_native_read_error_without_yielding_invalid_record
    assert_read_error(copy: true)
  end

  private

  def assert_read_error(copy:)
    bam = HTS::Bam.allocate
    bam.instance_variable_set(:@native, FakeNative.new([-2]))
    bam.instance_variable_set(:@header, HTS::Bam::Header.new)
    yielded = 0

    error = assert_raises(HTS::Bam::ReadError) do
      bam.each(copy:) { yielded += 1 }
    end

    assert_equal 0, yielded
    assert_match(/-2/, error.message)
  end
end
