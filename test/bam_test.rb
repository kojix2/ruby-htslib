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
      format_type = "#{format}_#{type}"

      define_method "#{format_type}" do
        eval("@#{format_type} ||= HTS::Bam.new(public_send(\"path_#{format_type}\"))")
      end

      define_method "test_new_#{format_type}" do
        b = HTS::Bam.new(public_send("path_#{format_type}"))
        assert_instance_of HTS::Bam, b
        b.close
        assert_equal true, b.closed?
      end

      define_method "test_open_#{format_type}" do
        b = HTS::Bam.open(public_send("path_#{format_type}"))
        assert_instance_of HTS::Bam, b
        assert_equal false, b.closed?
        b.close
        assert_equal true, b.closed?
        assert_nil b.close
      end

      define_method "test_open_#{format_type}_with_block" do
        b = HTS::Bam.open(public_send("path_#{format_type}")) do |b|
          assert_instance_of HTS::Bam, b
        end
        assert_equal true, b.closed?
      end

      define_method "test_file_name_#{format_type}" do
        assert_equal public_send("path_#{format_type}"),
                     public_send("#{format_type}").file_name
      end

      define_method "test_mode_#{format_type}" do
        assert_equal "r", public_send("#{format_type}").mode
      end

      define_method "test_header_#{format_type}" do
        assert_instance_of HTS::Bam::Header, public_send("#{format_type}").header
      end

      define_method "test_format_#{format_type}" do
        assert_equal format, public_send("#{format_type}").format
      end

      define_method "test_format_version_#{format_type}" do
        assert_includes ["1", "1.6", "3.0"], public_send("#{format_type}").format_version
      end

      define_method "test_each_#{format_type}" do
        c = 0
        result = public_send("#{format_type}").all? do |r|
          c += 1
          r.is_a? HTS::Bam::Record
        end
        assert_equal true, result
        assert_equal 10, c
      end

      next unless format != "sam"

      define_method "test_query_#{format_type}" do
        arr = []
        public_send("#{format_type}").query("chr2:350-700") do |aln|
          arr << aln.pos
        end
        assert_equal [341, 658], arr
      end
    end
  end

  # def test_initialize_no_file
  #   assert_raises(StandardError) { HTS::Bam.new("/tmp/no_such_file") }
  # end
end
