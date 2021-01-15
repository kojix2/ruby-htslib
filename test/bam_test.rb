require_relative 'test_helper'

class BamTest < Minitest::Test
  def setup
    @bam = HTS::Bam.new(File.expand_path('assets/poo.sort.bam', __dir__))
  end

  def test_initialize_sam
    skip
    sam = HTS::Bam.new(File.expand_path('assets/poo.sort.sam', __dir__))
    assert_instance_of HTS::Bam, sam
  end

  def test_initialize_bam
    assert_instance_of HTS::Bam, @bam
  end

  def test_initialize_no_file
    assert_raises(StandardError) { HTS::Bam.new('no_file') }
  end
end
