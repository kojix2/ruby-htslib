# frozen_string_literal: true

require_relative "test_helper"

class BamTest < Minitest::Test
  def teardown
    %w[bam sam cram].each do |format|
      %w[string uri].each do |type|
        eval "@#{format}_#{type}&.close"
      end
    end
  end

  def bam(ft)
    public_send(ft.to_s)
  end

  def bam_path(ft)
    public_send("path_#{ft}")
  end

  %w[bam sam cram].each do |format|
    define_method "path_#{format}_string" do
      Fixtures["moo.#{format}"]
    end

    define_method "path_#{format}_uri" do
      "https://raw.githubusercontent.com/kojix2/ruby-htslib/develop/test/fixtures/moo.#{format}"
    end
  end

  %w[bam sam cram].each do |format|
    %w[string uri].each do |type|
      ft = "#{format}_#{type}"

      define_method ft.to_s do
        eval("@#{ft} ||= HTS::Bam.new(public_send(\"path_#{ft}\"))")
      end

      define_method "test_new_#{ft}" do
        b = HTS::Bam.new(bam_path(ft))
        assert_instance_of HTS::Bam, b
        b.close
        assert_equal true, b.closed?
      end

      define_method "test_open_#{ft}" do
        b = HTS::Bam.open(bam_path(ft))
        assert_instance_of HTS::Bam, b
        assert_equal false, b.closed?
        b.close
        assert_equal true, b.closed?
        assert_nil b.close
      end

      define_method "test_open_#{ft}_with_block" do
        f = HTS::Bam.open(bam_path(ft)) do |b|
          assert_instance_of HTS::Bam, b
        end
        assert_equal true, f.closed?
      end

      define_method "test_file_name_#{ft}" do
        assert_equal bam_path(ft),
                     bam(ft).file_name
      end

      define_method "test_mode_#{ft}" do
        assert_equal "r", bam(ft).mode
      end

      define_method "test_header_#{ft}" do
        assert_instance_of HTS::Bam::Header, bam(ft).header
      end

      define_method "test_file_format_#{ft}" do
        assert_equal format, bam(ft).file_format
      end

      define_method "test_file_format_version_#{ft}" do
        assert_includes ["1", "1.6", "3.0"], bam(ft).file_format_version
      end

      define_method "test_each_#{ft}" do
        c = 0
        result = bam(ft).all? do |r|
          c += 1
          r.is_a? HTS::Bam::Record
        end
        assert_equal true, result
        assert_equal 10, c
      end

      next unless format != "sam"

      define_method "test_query_#{ft}" do
        arr = []
        bam(ft).query("chr2:350-700") do |aln|
          arr << aln.pos
        end
        assert_equal [341, 658], arr
      end
    end
  end

  def test_initialize_no_file_bam
    stderr_old = $stderr.dup
    $stderr.reopen(File::NULL)
    assert_raises(Errno::ENOENT) { HTS::Bam.new("/tmp/no_such_file") }
    $stderr.flush
    $stderr.reopen(stderr_old)
  end
end
