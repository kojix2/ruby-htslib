# frozen_string_literal: true

require_relative "test_helper"

class FaidxTest < Minitest::Test
  def setup
    @fai = HTS::Faidx.new(Fixtures["random.fa"])
  end

  def test_initialize_fai
    assert_instance_of HTS::Faidx, @fai
    stderr_old = $stderr.dup
    $stderr.reopen(File::NULL)
    assert_raises { HTS::Faidx.new("foo") }
    $stderr.flush
    $stderr.reopen(stderr_old)
  end

  def test_open
    # FIXME: API
    faidx = HTS::Faidx.open(Fixtures["random.fa"])
    assert_instance_of HTS::Faidx, faidx
    faidx.close
    HTS::Faidx.open(Fixtures["random.fa"]) do |f|
      assert_instance_of HTS::Faidx, f
    end
  end

  def test_struct
    assert_equal false, @fai.struct.null?
  end

  def test_close
    assert_nil @fai.close
  end

  def test_closed?
    skip
    assert_equal false, @fai.closed?
    @fai.close
    assert_equal true, @fai.closed?
  end

  def test_size
    assert_equal 5, @fai.size
  end

  def test_length
    assert_equal 5, @fai.length
  end

  def test_seq_len
    assert_equal 500, @fai.seq_len("chr1")
    assert_equal 500, @fai.seq_len(:chr1)
    assert_raises(ArgumentError) { @fai.seq_len(nil) }
    assert_nil @fai.seq_len("chr")
  end

  def test_names
    assert_equal %w[chr1 chr2 chr3 chr4 chr5], @fai.names
  end

  def test_keys
    assert_equal %w[chr1 chr2 chr3 chr4 chr5], @fai.keys
  end

  def test_seq
    assert_equal "TTGTGGAGAC", @fai.seq("chr1:1-10")
    assert_equal "TTGTGGAGAC", @fai.seq(:chr1, 0, 9)
    assert_equal "ACTTAGTTGA", @fai.seq("chr2:11-20")
    assert_equal "ACTTAGTTGA", @fai.seq(:chr2, 10, 19)
  end

  def test_fetch
    assert_equal "TTGTGGAGAC", @fai.fetch("chr1:1-10")
    assert_equal "TTGTGGAGAC", @fai.fetch(:chr1, 0, 9)
    assert_equal "ACTTAGTTGA", @fai.fetch("chr2:11-20")
    assert_equal "ACTTAGTTGA", @fai.fetch(:chr2, 10, 19)
  end
end
