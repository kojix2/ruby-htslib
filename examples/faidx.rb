#!/usr/bin/env ruby
# frozen_string_literal: true

require "htslib"

# Fetch a subsequence from an indexed FASTA file. Numeric coordinates passed
# to fetch_seq are zero-based and inclusive at both ends.
#
# Usage: ruby examples/faidx.rb [reference.fa] [name] [start] [stop]

fasta_path, sequence_name, start_arg, stop_arg = ARGV
fasta_path ||= File.expand_path("../test/fixtures/random.fa", __dir__)
start_pos = start_arg ? Integer(start_arg) : 0
stop_pos = stop_arg && Integer(stop_arg)

HTS::Faidx.open(fasta_path) do |fasta|
  name = sequence_name || fasta.names.first
  stop = stop_pos || [start_pos + 49, fasta.seq_len(name) - 1].min

  puts ">#{name}:#{start_pos + 1}-#{stop + 1}"
  puts fasta.fetch_seq(name, start_pos, stop)
end
