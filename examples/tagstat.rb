# frozen_string_literal: true

require "json"
require "optparse"
require "htslib"

options = {
  json: false,
  limit: 3,
  distinct_limit: 10_000,
  threads: nil
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby examples/tagstat.rb [options] input.bam"

  opts.on("--json", "Output JSON instead of TSV") do
    options[:json] = true
  end

  opts.on("--limit N", Integer, "Maximum number of examples per tag/type (default: #{options[:limit]})") do |value|
    options[:limit] = value
  end

  opts.on("--distinct-limit N", Integer,
          "Maximum distinct values to track exactly (default: #{options[:distinct_limit]})") do |value|
    options[:distinct_limit] = value
  end

  opts.on("-t", "--threads N", Integer, "Number of threads for BAM/CRAM decoding") do |value|
    options[:threads] = value
  end
end

parser.parse!

input = ARGV.shift
unless input
  warn parser
  exit 1
end

if options[:limit].negative?
  warn "--limit must be >= 0"
  exit 1
end

if options[:distinct_limit].negative?
  warn "--distinct-limit must be >= 0"
  exit 1
end

if options[:threads]&.negative?
  warn "--threads must be >= 0"
  exit 1
end

stats = Hash.new do |hash, key|
  hash[key] = {
    tag: key[0],
    type: key[1],
    reads: 0,
    examples: [],
    example_keys: Set.new,
    distinct_values: Set.new,
    distinct_overflow: false
  }
end

def formatted_example(value)
  case value
  when Array
    "len=#{value.length}"
  when String
    string_preview(value)
  else
    value.to_s
  end
end

def string_preview(value)
  preview = value.split(/[,\t;]/, 2).first || ""
  preview = value if preview.empty? && !value.empty?
  preview.length > 40 ? "#{preview[0, 37]}..." : preview
end

def distinct_value_key(value)
  case value
  when Array
    value.join(",")
  else
    value.to_s
  end
end

total_reads = 0

HTS::Bam.open(input, threads: options[:threads]) do |bam|
  bam.each do |record|
    total_reads += 1

    record.aux.each_with_type do |tag, type, value|
      stat = stats[[tag, type]]
      stat[:reads] += 1

      example = formatted_example(value)
      if stat[:examples].length < options[:limit] && !stat[:example_keys].include?(example)
        stat[:examples] << example
        stat[:example_keys] << example
      end

      next if stat[:distinct_overflow]

      distinct_key = distinct_value_key(value)
      stat[:distinct_values] << distinct_key
      if stat[:distinct_values].length > options[:distinct_limit]
        stat[:distinct_values].clear
        stat[:distinct_overflow] = true
      end
    end
  end
end

rows = stats.values.sort_by { |stat| [-stat[:reads], stat[:tag], stat[:type]] }.map do |stat|
  distinct = if stat[:distinct_overflow]
               ">#{options[:distinct_limit]}"
             else
               stat[:distinct_values].length
             end
  percent = total_reads.zero? ? 0.0 : (stat[:reads] * 100.0 / total_reads)

  {
    tag: stat[:tag],
    type: stat[:type],
    reads: stat[:reads],
    percent: percent.round(1),
    distinct: distinct,
    examples: stat[:examples]
  }
end

if options[:json]
  puts JSON.pretty_generate(total_reads: total_reads, tags: rows)
else
  puts %w[tag type reads percent distinct examples].join("\t")
  rows.each do |row|
    puts [
      row[:tag],
      row[:type],
      row[:reads],
      format("%.1f", row[:percent]),
      row[:distinct],
      row[:examples].join(",")
    ].join("\t")
  end
end
