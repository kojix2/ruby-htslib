# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"

class TagstatExampleTest < Minitest::Test
  def test_tsv_output
    stdout, stderr, status = run_tagstat(Fixtures["poo.sort.bam"])

    assert status.success?, stderr
    lines = stdout.lines.map(&:chomp)
    assert_equal "tag\ttype\treads\tpercent\tdistinct\texamples", lines.first
    assert(lines.any? { |line| line.start_with?("MC\tZ\t") })
    assert(lines.any? { |line| line.start_with?("AS\tC\t") })
    assert(lines.any? { |line| line.start_with?("XS\tC\t") })
  end

  def test_json_output
    stdout, stderr, status = run_tagstat("--json", Fixtures["poo.sort.bam"])

    assert status.success?, stderr

    payload = JSON.parse(stdout)
    assert_equal 31, payload.fetch("total_reads")
    tags = payload.fetch("tags")
    assert(tags.any? { |tag| tag["tag"] == "MC" && tag["type"] == "Z" })
    assert(tags.any? { |tag| tag["tag"] == "AS" && tag["type"] == "C" })
    assert(tags.any? { |tag| tag["tag"] == "XS" && tag["type"] == "C" })
  end

  private

  def run_tagstat(*args)
    Open3.capture3(
      RbConfig.ruby,
      "-Ilib",
      "-Iext/htslib_native",
      "examples/tagstat.rb",
      *args,
      chdir: File.expand_path("..", __dir__)
    )
  end
end
