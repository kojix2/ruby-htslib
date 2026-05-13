# frozen_string_literal: true

require_relative "test_helper"

class HTSTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil HTS::VERSION
  end

  def test_hts_version
    refute_nil HTS::LibHTS.hts_version
  end

  def test_hts_new
    assert_raises(TypeError) do
      HTS::Hts.new
    end
  end

  def test_sam_itr_next_passes_null_bgzf_for_cram
    htsfp = HTS::LibHTS::HtsFile.new(FFI::MemoryPointer.new(HTS::LibHTS::HtsFile.size))
    itr = HTS::LibHTS::HtsItr.new(FFI::MemoryPointer.new(HTS::LibHTS::HtsItr.size))
    record = FFI::MemoryPointer.new(:char, 1)
    captured_bgzf = nil

    htsfp[:is_cram] = 1
    HTS::LibHTS.stub(:hts_itr_next, ->(bgzf, _itr, _record, _data) {
      captured_bgzf = bgzf
      0
    }) do
      assert_equal 0, HTS::LibHTS.sam_itr_next(htsfp, itr, record)
    end

    assert captured_bgzf.null?
  end

  def test_sam_itr_next_uses_bgzf_pointer_for_bgzf
    htsfp = HTS::LibHTS::HtsFile.new(FFI::MemoryPointer.new(HTS::LibHTS::HtsFile.size))
    bgzf = HTS::LibHTS::BGZF.new(FFI::MemoryPointer.new(HTS::LibHTS::BGZF.size))
    itr = HTS::LibHTS::HtsItr.new(FFI::MemoryPointer.new(HTS::LibHTS::HtsItr.size))
    record = FFI::MemoryPointer.new(:char, 1)
    captured_bgzf = nil

    htsfp[:is_bgzf] = 1
    htsfp[:fp][:bgzf] = bgzf
    HTS::LibHTS.stub(:hts_itr_next, ->(fp, _itr, _record, _data) {
      captured_bgzf = fp
      0
    }) do
      assert_equal 0, HTS::LibHTS.sam_itr_next(htsfp, itr, record)
    end

    assert_equal bgzf.to_ptr.address, captured_bgzf.to_ptr.address
  end

  def test_sam_itr_next_uses_multi_iterator_entrypoint
    htsfp = HTS::LibHTS::HtsFile.new(FFI::MemoryPointer.new(HTS::LibHTS::HtsFile.size))
    itr = HTS::LibHTS::HtsItr.new(FFI::MemoryPointer.new(HTS::LibHTS::HtsItr.size))
    record = FFI::MemoryPointer.new(:char, 1)
    called = false

    htsfp[:is_cram] = 1
    itr[:multi] = 1
    HTS::LibHTS.stub(:hts_itr_multi_next, ->(_htsfp, _itr, _record) {
      called = true
      0
    }) do
      assert_equal 0, HTS::LibHTS.sam_itr_next(htsfp, itr, record)
    end

    assert called
  end
end
