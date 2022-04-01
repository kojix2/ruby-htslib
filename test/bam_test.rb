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

  %w[bam sam cram].each do |format|
    define_method "path_#{format}_string" do
      Fixtures["moo.#{format}"]
    end

    define_method "path_#{format}_uri" do
      "https://raw.githubusercontent.com/kojix2/ruby-htslib/develop/test/fixtures/moo.#{format}"
    end

    %w[string uri].each do |type|
      define_method "#{format}_#{type}" do
        eval("@#{format}_#{type} ||= HTS::Bam.new(public_send(\"path_#{format}_#{type}\"))")
      end

      define_method "test_new_#{format}_#{type}" do
        b = HTS::Bam.new(public_send("path_#{format}_#{type}"))
        assert_instance_of HTS::Bam, b
        b.close
        assert_equal true, b.closed?
      end

      define_method "test_open_#{format}_#{type}" do
        b = HTS::Bam.open(public_send("path_#{format}_#{type}"))
        assert_instance_of HTS::Bam, b
        b.close
        assert_equal true, b.closed?
      end

      define_method "test_open_#{format}_#{type}_with_block" do
        b = HTS::Bam.open(public_send("path_#{format}_#{type}")) do |b|
          assert_instance_of HTS::Bam, b
        end
        assert_equal true, b.closed?
      end

      define_method "test_file_name_#{format}_#{type}" do
        assert_equal public_send("path_#{format}_#{type}"),
                     public_send("#{format}_#{type}").file_name
      end

      define_method "test_mode_#{format}_#{type}" do
        assert_equal "r", public_send("#{format}_#{type}").mode
      end

      define_method "test_header_#{format}_#{type}" do
        assert_instance_of HTS::Bam::Header, public_send("#{format}_#{type}").header
      end

      define_method "test_format_#{format}_#{type}" do
        assert_equal format, public_send("#{format}_#{type}").format
      end

      define_method "test_format_version_#{format}_#{type}" do
        assert_includes ["1", "1.6", "3.0"], public_send("#{format}_#{type}").format_version
      end

      define_method "test_each_#{format}_#{type}" do
        c = 0
        result = public_send("#{format}_#{type}").all? do |r|
           c += 1
           r.is_a? HTS::Bam::Record
        end
        assert_equal true, result
        assert_equal 10, c
      end

      if format != "sam"
        define_method "test_query_#{format}_#{type}" do
          arr = []
          public_send("#{format}_#{type}").query("chr2:350-700") do |aln|
            arr << aln.start
          end
          assert_equal [341, 658], arr
        end
      end
    end
  end

  def test_initialize_no_file
    assert_raises(StandardError) { HTS::Bam.new("no_file") }
  end
end
