require "open3"
require "diffy"
require "colorize"

GCC = ENV["GCC"] || "gcc"

def extract_attach_functions(header_file_path)
  str = File.read(header_file_path)
  attach_function_count = str.scan(/attach_function/).count
  puts "count attach_function: #{attach_function_count}"

  str.scan(/attach_function.*\n?.*:.*(?=,)/)
     .map { |fn| fn.split(":").last }
end

def extract_native_functions(header_file_path)
  htslib_export_count = File.foreach(header_file_path).grep(/HTSLIB_EXPORT/).count
  puts "count HTSLIB_EXPORT: #{htslib_export_count}"

  preprocessed_header, stderr, status = Open3.capture3("#{GCC} -fpreprocessed -dD -E #{header_file_path}")
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
end

files = %w[bgzf cram hfile hts kfunc sam tbx vcf]

files.each do |file|
  puts " #{file} ".colorize(:white).on_blue.bold
  h_file_path = "../htslib/htslib/#{file}.h"
  rb_file_path = "../lib/hts/libhts/#{file}.rb"

  h_functions = extract_native_functions(h_file_path).join("\n")
  rb_functions = extract_attach_functions(rb_file_path).join("\n")

  diffy = Diffy::Diff.new(h_functions, rb_functions, context: 0)

  puts diffy.to_s(:color)
  puts
end
