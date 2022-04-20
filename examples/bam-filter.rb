#! /usr/bin/env ruby
# frozen_string_literal: true

# https://github.com/brentp/hts-nim-tools/blob/master/src/bam_filter.nim

require "optparse"
require "htslib"

OptionParser.new do |parser|
  nthreads = 0
  output_format = ".sam"
  output_file   = "-"

  parser.program_name = "bam-filter"
  parser.banner = <<~MSG

    Usage: #{File.basename(__FILE__)} [options] <bam_file>

  MSG
  parser.summary_width = 23
  parser.on(
    "-e", "--expression EXPR", "eval ruby code. presets variables are:",
    "fields [maq start pos stop name mpos seq cigar qual isize]",
    "flags  [paired proper_pair unmapped mate_unmapped reverse",
    " mate_reverse read1 read2 secondary qcfail dup supplementary]"
  ) { |v| @expr = v }
  parser.on("-t", "--threads NUM", Integer) { |v| nthreads = v }
  # parser.on("-f", "--fasta PATH") { |v| p v }
  parser.on("-o", "--output PATH") { |v| output_file = v }
  parser.on("-S", "--sam", "Output SAM") { |_v| output_format = ".sam" }
  parser.on("-b", "--bam", "Output BAM") { |_v| output_format = ".bam" }
  parser.on("-d", "--debug", "print expression") { @debug = true }
  parser.parse!(ARGV) # make it outside the scope of eval.

  if ARGV.empty?
    warn parser.help
    exit(1)
  elsif @expr.nil?
    warn "Expression is required"
    exit(1)
  end

  # make it outside the scope of eval.
  # FIXME: CRAM
  @bam = HTS::Bam.open(ARGV[0], "r", threads: nthreads)

  mode = case (output_format ||= File.extname(output_file))
         when ".bam" then "wb"
         when ".sam", "" then "w"
         else warn "Unknown output format: #{output_format}"
              "w"
         end
  @bam_out = HTS::Bam.open(output_file, mode)
  @bam_out.write_header(@bam.header)
end

@expr = String.new.tap do |s|
  # make it outside the scope of eval.
  flag_names = %w[paired proper_pair unmapped mate_unmapped
                  reverse mate_reverse read1 read2
                  secondary qcfail dup supplementary]
  use_flag = flag_names.any? { |name| @expr.include?(name) }
  s << "mapq  = r.mapping_quality\n" if @expr.include? "mapq"
  s << "start = r.start\n"           if @expr.include? "start"
  s << "pos   = r.start + 1\n"       if @expr.include? "pos"
  s << "stop  = r.stop\n"            if @expr.include? "stop"
  s << "name  = r.qname\n"           if @expr.include? "name"
  s << "mpos  = r.mpos + 1\n"    if @expr.include? "mpos"
  s << "seq   = r.sequence\n"        if @expr.include? "seq"
  s << "cigar = r.cigar.to_a\n"      if @expr.include? "cigar"
  s << "qual  = r.base_qualities\n"  if @expr.include? "qual"
  s << "isize = r.insert_size\n"     if @expr.include? "isize"
  if use_flag
    s << "flag  = r.flag\n" # HTS::Bam::Flag
    flag_names.each do |n|
      s << "#{n} = flag.#{n}?\n" if @expr.include? n
    end
  end
  # Overwrite flag(HTS::Bam::Flag) with integer.
  s << "flag = r.flag.flag_value\n" if @expr.include? "flag"
  s << @expr
end

if @debug
  puts @expr
  exit
end

@bam.each do |r|
  @bam_out.write(r) if eval(@expr)
end

@bam.close
@bam_out.close
