# frozen_string_literal: true

require_relative "test_helper"

class HTSTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil HTS::VERSION
  end

  def test_hts_version
    refute_nil HTS::LibHTS.hts_version
  end
end
