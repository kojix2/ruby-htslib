# frozen_string_literal: true

require "htslib"

# Example: Reading base modifications (MM/ML tags) from SAM/BAM/CRAM files
#
# Usage:
#   ruby examples/base_mod.rb [input.bam]
#
# Without arguments, uses a bundled test file with base modifications.

input_path = ARGV[0] || File.expand_path("../htslib/test/base_mods/MM-chebi.sam", __dir__)

HTS::Bam.open(input_path) do |bam|
  bam.each do |record|
    puts "Record: #{record.qname}"
    puts "Sequence: #{record.seq}"
    
    base_mod = record.base_mod
    
    # Check what modification types are present
    mod_types = base_mod.recorded_types
    if mod_types.empty?
      puts "No modifications found"
      next
    end
    
    puts "Modification types:"
    mod_types.each do |code|
      info = base_mod.query_type(code)
      type_name = code > 0 ? code.chr : "ChEBI:#{-code}"
      puts "  #{type_name} on #{info[:canonical]} (strand: #{info[:strand]})"
    end
    
    # Iterate through all modified positions
    puts "Modified positions:"
    base_mod.each_position do |position|
      print "  pos #{position.position}: "
      
      position.modifications.each do |mod|
        code_str = mod.code
        prob = mod.probability
        
        if prob
          print "#{mod.canonical}->#{code_str} (#{(prob * 100).round(1)}%) "
        else
          print "#{mod.canonical}->#{code_str} "
        end
      end
      puts
    end
    
    # Show convenience methods
    if base_mod.any? { |pos| pos.methylated? }
      methylated_positions = base_mod.select { |pos| pos.methylated? }.map(&:position)
      puts "Methylated (m) at: #{methylated_positions.join(', ')}"
    end
    
    # Example: Random access to specific position
    if (first_mod = base_mod.first)
      example_pos = first_mod.position
      if (mod_at_pos = base_mod.at_pos(example_pos))
        codes = mod_at_pos.modifications.map(&:code).join(", ")
        puts "Random access at_pos(#{example_pos}): #{codes}"
      end
    end
    
    puts
  end
end
