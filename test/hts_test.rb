# frozen_string_literal: true

require_relative "test_helper"

class HTSTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil HTS::VERSION
  end

  def test_native_backend_reports_htslib_version
    assert_match(/\A\d+\.\d+/, HTS::Native.htslib_version)
  end

  def test_hts_new
    assert_raises(TypeError) { HTS::Hts.new }
  end

  def test_removed_low_level_api_is_not_exposed
    refute HTS.const_defined?(:LibHTS, false)
    refute_respond_to HTS, :lib_path
    refute_respond_to HTS, :lib_path=
  end
end
