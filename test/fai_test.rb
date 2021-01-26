require_relative 'test_helper'

class FaiTest < Minitest::Test
  def setup
    @fai = HTS::Fai.new(File.expand_path('assets/random.fa', __dir__))
  end

  def test_initialize_fai
    assert_instance_of HTS::Fai, @fai
  end
end
