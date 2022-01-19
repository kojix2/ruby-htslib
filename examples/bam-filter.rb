#! /usr/bin/env ruby
# https://github.com/brentp/hts-nim-tools/blob/master/src/bam_filter.nim

require "optparse"
require "htslib"

OptionParser.new do |parser|
  parser.banner = "Usage: #{File.basename(__FILE__)} [parserions] <bam_file>"
  parser.on("-e", "--expression EXPR", "eval code from arg") { |v| @expr = v }
  # parser.on("-t", "--threads NUM") { |v| p v }
  # parser.on("-f", "--fasta PATH") { |v| p v }
  parser.on("-d", "--debug", "print expression") { @debug = true }
  parser.parse!(ARGV) # make it outside the scope of eval.
end

exit(1) if ARGV.size != 1

# FIXME: CRAM
bam = HTS::Bam.open(ARGV[0])

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
  s << "mpos  = r.mate_pos + 1\n"    if @expr.include? "mpos"
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

bam.each do |r|
  puts r if eval(@expr)
end

bam.close