# frozen_string_literal: true

require_relative "../test_helper"

class BamAuxTest < Minitest::Test
  def poo
    bam = HTS::Bam.new(Fixtures["poo.sort.bam"])
    alm = bam.first
    alm.aux
  end

  def colons
    bam = HTS::Bam.new(File.expand_path("../../htslib/test/colons.bam", __dir__))
    alm = bam.first
    alm.aux
  end

  %i[poo colons].each do |file_path|
    define_method "test_initialize_#{file_path}" do
      assert_instance_of HTS::Bam::Aux, public_send(file_path)
    end
  end
end
