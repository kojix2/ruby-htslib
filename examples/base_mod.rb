#!/usr/bin/env ruby
# frozen_string_literal: true

# Example usage of base modification API
# This demonstrates how to use the BaseMod class to extract
# DNA/RNA base modifications from BAM files with MM/ML tags

require "htslib"

# Example 1: Basic usage with a BAM file
puts "=== Example 1: Basic BaseMod Usage ==="
puts

# Note: This example requires a BAM file with MM/ML tags
# For demonstration, we'll show the API usage
# In practice, you'd use a real file with base modifications

if ARGV.empty?
  puts "Usage: ruby base_mod_example.rb <bam_file_with_modifications>"
  puts
  puts "This example shows how to use the BaseMod API."
  puts "You need a BAM file with MM (base modification) and ML (modification likelihood) tags."
  puts
  puts "Example with hypothetical data:"
  puts
  puts "  bam = HTS::Bam.new('methylation_data.bam')"
  puts "  "
  puts "  bam.each do |record|"
  puts "    base_mod = record.base_mod"
  puts "    "
  puts "    # Parse the MM/ML tags"
  puts "    n_types = base_mod.parse"
  puts "    next if n_types <= 0  # No modifications"
  puts "    "
  puts "    # Get modification types present"
  puts "    types = base_mod.modification_types"
  puts '    puts "Modification types: #{types.join(\', \')}"'
  puts "    "
  puts "    # Iterate over all modified positions"
  puts "    base_mod.each_position do |pos|"
  puts '      puts "Position #{pos.position} (strand #{pos.strand}):"'
  puts "      "
  puts "      pos.modifications.each do |mod|"
  puts '        puts "  #{mod.canonical} -> #{mod.code}"'
  puts '        puts "  Probability: #{mod.probability}" if mod.likelihood'
  puts "      end"
  puts "    end"
  puts "    "
  puts "    # Or query a specific position"
  puts "    pos_info = base_mod.at_pos(10)"
  puts "    if pos_info"
  puts '      puts "Modifications at position 10:"'
  puts "      pos_info.modifications.each do |mod|"
  puts '        puts "  #{mod}"'
  puts "      end"
  puts "    end"
  puts "    "
  puts "    # Array-style access"
  puts "    if base_mod[5]"
  puts '      puts "Position 5 is modified"'
  puts "    end"
  puts "    "
  puts "    # Check for specific modifications"
  puts "    base_mod.each_position do |pos|"
  puts "      if pos.methylated?"
  puts '        puts "Methylation found at position #{pos.position}"'
  puts "      end"
  puts "    end"
  puts "  end"
  puts
  exit 0
end

bam_file = ARGV[0]

unless File.exist?(bam_file)
  puts "Error: File not found: #{bam_file}"
  exit 1
end

HTS::Bam.open(bam_file) do |bam|
  count = 0
  modified_count = 0

  bam.each do |record|
    count += 1
    base_mod = record.base_mod

    begin
      # Try to parse modifications
      n_types = base_mod.parse
      next if n_types <= 0

      modified_count += 1

      puts "Record #{count}: #{record.qname}"
      puts "  Modification types: #{base_mod.modification_types.join(', ')}"

      # Show information about each modification type
      base_mod.modification_types.each do |type|
        info = base_mod.query_type(type)
        if info
          puts "  Type '#{type}': canonical=#{info[:canonical]}, strand=#{info[:strand]}, implicit=#{info[:implicit]}"
        end
      end

      # Show all modified positions
      positions = base_mod.to_a
      puts "  Modified positions: #{positions.length}"

      positions.each do |pos|
        puts "    #{pos}"
      end

      puts

      break if count >= 10 # Show first 10 records only
    rescue HTS::Error
      # Some records might not have valid modification data
      # This is normal for records without MM/ML tags
    end
  end

  puts "Summary:"
  puts "  Total records checked: #{count}"
  puts "  Records with modifications: #{modified_count}"
end
