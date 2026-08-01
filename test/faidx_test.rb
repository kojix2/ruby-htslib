# frozen_string_literal: true

require_relative "test_helper"

class FaidxTest < Minitest::Test
  def setup
    @fasta = HTS::Faidx.new(Fixtures["random.fa"])
    @fastq = HTS::Faidx.new(Fixtures["moo.fastq"], format: :fastq)
  end

  def teardown
    @fasta&.close
    @fastq&.close
  end

  def test_initialize_fai
    assert_instance_of HTS::Faidx, @fasta
    silence_stderr do
      assert_raises { HTS::Faidx.new("foo") }
    end
  end

  def test_open
    faidx = HTS::Faidx.open(Fixtures["random.fa"])
    assert_instance_of HTS::Faidx, faidx
    faidx.close
    HTS::Faidx.open(Fixtures["random.fa"]) do |f|
      assert_instance_of HTS::Faidx, f
    end
  end

  def test_closed?
    assert_equal false, @fasta.closed?
    assert_nil @fasta.close
    assert_equal true, @fasta.closed?
  end

  def test_native_handle_is_not_public
    refute_respond_to @fasta, :struct
    refute_respond_to @fasta, :to_ptr
  end

  def test_close
    assert_nil @fasta.close
  end

  def test_format
    assert_equal :fasta, @fasta.format
    assert_equal :fastq, @fastq.format
  end

  def test_size
    assert_equal 5, @fasta.size
  end

  def test_length
    assert_equal 5, @fasta.length
  end

  def test_seq_len
    assert_equal 500, @fasta.seq_len("chr1")
    assert_equal 500, @fasta.seq_len(:chr1)
    assert_raises(ArgumentError) { @fasta.seq_len(nil) }
    assert_raises(ArgumentError) { @fasta.seq_len("chr") }
  end

  def test_names
    assert_equal %w[chr1 chr2 chr3 chr4 chr5], @fasta.names
  end

  def test_has_seq
    assert_equal true, @fasta.has_seq?("chr1")
    assert_equal false, @fasta.has_seq?("chrX")
  end

  def test_fetch_seq
    assert_equal "TTGTGGAGAC", @fasta.fetch_seq(:chr1, 0, 9)
    assert_equal "ACTTAGTTGA", @fasta.fetch_seq(:chr2, 10, 19)
  end

  def test_fetch_full_sequence
    assert_equal 500, @fasta.fetch_seq("chr1").length
  end

  def test_fetch_qual
    assert_equal "2222222222222222222222222222222222222222", @fastq.fetch_qual(@fastq.names.first)
    assert_equal "22222", @fastq.fetch_qual(@fastq.names.first, 0, 4)
  end

  def test_fetch_qual_on_fasta_raises
    assert_raises(HTS::Error) { @fasta.fetch_qual("chr1") }
  end

  def test_build_index
    Tempfile.create(["faidx", ".fa"]) do |file|
      file.write(">chr1\nACGT\n")
      file.flush
      HTS::Faidx.build_index(file.path)
      assert File.exist?("#{file.path}.fai")
    ensure
      File.delete("#{file.path}.fai") if File.exist?("#{file.path}.fai")
      File.delete("#{file.path}.gzi") if File.exist?("#{file.path}.gzi")
    end
  end

  def test_closed_object_raises
    @fasta.close
    assert_raises(IOError) { @fasta.length }
    assert_raises(IOError) { @fasta.names }
    assert_raises(IOError) { @fasta.has_seq?("chr1") }
    assert_raises(IOError) { @fasta.seq_len("chr1") }
    assert_raises(IOError) { @fasta.fetch_seq("chr1") }
    assert_raises(IOError) { @fasta.fetch_qual("chr1") }
  end

  def test_invalid_range
    assert_raises(ArgumentError) { @fasta.fetch_seq("chr1", -1, 10) }
    assert_raises(ArgumentError) { @fasta.fetch_seq("chr1", 0, -1) }
    assert_raises(ArgumentError) { @fasta.fetch_seq("chr1", 10, 5) }
    assert_raises(ArgumentError) { @fasta.fetch_seq("chr1", 0, 500) }
    assert_raises(ArgumentError) { @fasta.fetch_seq("nonexistent", 0, 10) }
  end

  def test_initialize_with_block_raises
    assert_raises(ArgumentError) { HTS::Faidx.new(Fixtures["random.fa"]) {} }
  end
end
