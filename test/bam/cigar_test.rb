require_relative '../test_helper'

class CigarTest < Minitest::Test
  def poo
    bam = HTS::Bam.new(Fixtures['poo.sort.bam'])
    alm = bam.first
    alm.cigar
  end

  def colons
    bam = HTS::Bam.new(File.expand_path('../../htslib/test/colons.bam', __dir__))
    alm = bam.first
    alm.cigar
  end

  %i[poo colons].each do |fname|
    define_method "test_initialize_#{fname}" do
      assert_instance_of HTS::Bam::Cigar, public_send(fname)
    end

    define_method "test_to_s_#{fname}" do
      assert_equal ({ poo: '', colons: '10M' }[fname]), public_send(fname).to_s
    end

    define_method "test_to_a_#{fname}" do
      assert_equal ({ poo: [], colons: [[10, 'M']] }[fname]), public_send(fname).to_a
    end
  end
end
