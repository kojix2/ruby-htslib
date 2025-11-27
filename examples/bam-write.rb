#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Writing BAM files
#
# This example demonstrates how to:
# - Read BAM files and write modified records to a new BAM file
# - Modify record fields (MAPQ, flags, positions, etc.)
# - Add, update, and delete auxiliary tags
# - Filter records based on criteria
#
# Usage: bam-write.rb <input.bam> <output.bam>

require "htslib"

def main
  if ARGV.size < 2
    warn "Usage: #{$PROGRAM_NAME} <input.bam> <output.bam>"
    warn ""
    warn "This example reads a BAM file, modifies records, and writes to a new file."
    warn ""
    warn "Examples:"
    warn "  #{$PROGRAM_NAME} input.bam output.bam"
    exit 1
  end

  input_path = ARGV[0]
  output_path = ARGV[1]

  # Open input BAM file
  input_bam = HTS::Bam.new(input_path)
  header = input_bam.header

  # Open output BAM file for writing
  output_bam = HTS::Bam.new(output_path, "wb")
  output_bam.write_header(header)

  written_count = 0
  filtered_count = 0

  # Process each record
  input_bam.each do |record|
    # Example 1: Filter records by mapping quality
    # Skip records with low mapping quality
    if record.mapq < 10
      filtered_count += 1
      next
    end

    # Example 2: Modify record fields
    # Adjust mapping quality for high-confidence alignments
    if record.mapq > 50
      record.mapq = 60 # Cap at 60
    end

    # Example 3: Modify flags
    # Mark duplicates (example logic)
    if record.pos % 100 == 0 # Arbitrary example
      record.flag
      # This is just an example - real duplicate marking is more complex
      # flag |= 1024  # Set duplicate flag
    end

    # Example 4: Work with auxiliary tags
    aux = record.aux

    # Add or update tags using type-specific methods
    aux.update_int("AS", record.mapq * 2)  # Alignment score based on MAPQ
    aux.update_string("PG", "bam-write")   # Program name

    # Or use the []= operator (auto-detects type)
    aux["NM"] = 0              # Reset edit distance (example)
    aux["ZP"] = "processed"    # Custom processing flag

    # Add custom quality metrics
    if record.mapq > 30
      aux.update_float("ZQ", 0.95)  # High quality score
      aux["HQ"] = 1                 # High quality flag
    else
      aux.update_float("ZQ", 0.50)  # Medium quality score
    end

    # Delete tags if needed (example: remove XS tag)
    aux.delete("XS") if aux.key?("XS")

    # Example 5: Add array tags
    # Add custom base quality distribution (mock data)
    if record.seq && record.seq.length > 0
      # Count ACGT bases (simplified example)
      seq = record.seq
      base_counts = [
        seq.count("A"),
        seq.count("C"),
        seq.count("G"),
        seq.count("T")
      ]
      aux.update_array("BC", base_counts)
    end

    # Write modified record to output
    output_bam.write(record)
    written_count += 1

    # Print progress every 10000 records
    warn "Processed: #{written_count} written, #{filtered_count} filtered..." if (written_count % 10_000).zero?
  end

  # Clean up
  input_bam.close
  output_bam.close

  puts "Done!"
  puts "  Records written: #{written_count}"
  puts "  Records filtered: #{filtered_count}"
  puts "  Total processed: #{written_count + filtered_count}"
  puts "  Output: #{output_path}"
end

main if $PROGRAM_NAME == __FILE__
