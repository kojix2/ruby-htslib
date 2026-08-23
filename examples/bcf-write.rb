#!/usr/bin/env ruby
# frozen_string_literal: true

require "htslib"

# Copy a VCF/BCF file while adding an INFO field. The output index is created
# when the output file is closed.
#
# Usage: ruby examples/bcf-write.rb INPUT.bcf OUTPUT.bcf

input_path, output_path = ARGV
abort "Usage: #{$PROGRAM_NAME} INPUT.bcf OUTPUT.bcf" unless input_path && output_path

HTS::Bcf.open(input_path) do |input|
  input.header.add_info(
    "RDP",
    number: 1,
    type: :integer,
    description: "Read depth copied by the ruby-htslib example"
  )

  HTS::Bcf.open(output_path, "wb", build_index: true) do |output|
    output.write_header(input.header)

    input.each do |record|
      record.info["RDP"] = record.info["DP"] || [0]
      output << record
    end
  end
end
