#!/usr/bin/env ruby

require "open3"

Dir.chdir(__dir__)

header_path = File.join("..", "htslib", "htslib", "#{ARGV[0]}.h")

htslib_export_count = File.foreach(header_path).grep(/HTSLIB_EXPORT/).count
puts "count HTSLIB_EXPORT: #{htslib_export_count}"

preprocessed_header, stderr, status = Open3.capture3("gcc -fpreprocessed -dD -E #{header_path}")
raise stderr unless status.success?

preprocessed_header
  .gsub(/\n/, "")
  .gsub(/;/, ";\n")
  .scan(/(?<=HTSLIB_EXPORT).*(?=;)/)
  .map do
    _1.strip
      .gsub(/\s+/, " ")
      .split("(")
      .first
      .split(" ")
      .last
      .gsub(/^\**/, "")
  end
  .each { |fn| puts fn }
