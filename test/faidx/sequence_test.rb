# frozen_string_literal: true

require_relative "../test_helper"

class FaidxSequenceTest < Minitest::Test
  def setup
    @fai = HTS::Faidx.new(Fixtures["random.fa"])
    @seq = @fai["chr1"]
  end

  def nucleotide
    seq = <<~DNA
      TTGTGGAGACGGGAAGCGCTGGAATAGTGTGTAACGTGAAGACCCGCGTT
      TGCTTGTTATTGGTTCGGCCGATGGTGTGTAGCGCACAGCCAGTGTCAGA
      CGACCTTCAAGGAACGGTTCAAGATAGAGTATACATCGGATGGTTGACTT
      TAGAAGAAACCCTGGCATTCATGTTGTCCACCCAAGGAGGAGCGCTCATT
      CCGGGTCGTCTTCTGTGGGTTACCTGCTAACTCTAACAGCTCAAAAGGGG
      ATTTGTGGTCTACACTCTACACGCGAACTCTACACACTGATGTAGAGGCT
      ACACATCGCAGGGCGGAGTCAGTGGCAGCTAGCGTCCGTCCCCAGTCCGG
      CAATCCGCTGCACCACAGAGTGAACCAACGCCATGCTTATCGCCATTTGT
      CAACCATAAAAAAATCGGCACAGACCCCCTATTATGCATGTATACTTACT
      CTAGTACTCAAGCTCACAACGTTCGGAAACGAGAATTGTAAGGAGTGACG
    DNA
    seq.gsub(/[\r\n]/, "")
  end

  def test_length
    assert_equal 500, @seq.length
  end

  def test_size
    assert_equal 500, @seq.size
  end

  def test_seq

    assert_equal nucleotide, @seq.seq
    assert_equal "TTG", @seq.seq(0, 2)
    assert_raises { @seq.seq(-1, 3) }
    assert_raises { @seq.seq(2, 0) }
    assert_raises { @seq.seq(0, 500) }
  end

  def test_at
    assert_equal "TTG", @seq[0..2]
    assert_equal "TT", @seq[0...2]
    assert_equal "T", @seq[1]
    assert_equal "TTG", @seq[..2]
    assert_equal "TT", @seq[...2]
    assert_equal "ACG", @seq[497..]
    assert_equal "ACG", @seq[497...]
    assert_equal "T", @seq[0..0]
    assert_equal "G", @seq[-1]
    assert_equal "ACG", @seq[-3..-1]
    assert_equal "AC", @seq[-3...-1]
    assert_equal "TTG", @seq[..-498]
    assert_equal "TT", @seq[...-498]
    assert_equal "ACG", @seq[-3..]
    assert_equal "ACG", @seq[-3...]
    assert_equal nucleotide, @seq[0..-1]
    assert_equal nucleotide, @seq[0...500]
    assert_equal nucleotide, @seq[nil..]
    assert_raises { @seq[0...0] }
    assert_raises { @seq[-1..-3] }
    assert_raises { @seq[1..0] }
    assert_raises { @seq[500] }
    assert_raises { @seq[-501] }
    assert_raises { @seq[0..500] }
    assert_raises { @seq[0...501] }
    assert_raises { @seq[500..500] }
    assert_raises { @seq[500...501] }
    assert_raises { @seq[..500] }
    assert_raises { @seq[...501] }
    assert_raises { @seq[-501..-1] }
    assert_raises { @seq[-501...-1] }
    assert_raises { @seq[-501..] }
    assert_raises { @seq[-501...] } 
    assert_raises { @seq[-502..-501] }
    assert_raises { @seq[-502...-500] }
    assert_raises { @seq[-501..500] }
    assert_raises { @seq[-501...501] }
  end
end
