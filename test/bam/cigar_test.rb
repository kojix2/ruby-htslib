# frozen_string_literal: true

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

  %i[poo colons].each do |file_path|
    define_method "test_initialize_#{file_path}" do
      assert_instance_of HTS::Bam::Cigar, public_send(file_path)
    end

    define_method "test_to_s_#{file_path}" do
      assert_equal ({ poo: '', colons: '10M' }[file_path]), public_send(file_path).to_s
    end

    define_method "test_to_a_#{file_path}" do
      assert_equal ({ poo: [], colons: [[10, 'M']] }[file_path]), public_send(file_path).to_a
    end
  end
end
