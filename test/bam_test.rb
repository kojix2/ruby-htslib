require_relative 'test_helper'

class BamTest < Minitest::Test
  def setup
    @bam = HTS::Bam.new(File.expand_path("assets/poo.sort.bam",__dir__))
  end

  def test_initialize
    assert_instance_of HTS::Bam, @bam
  end
end
