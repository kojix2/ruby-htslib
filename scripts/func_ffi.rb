#!/usr/bin/env ruby

Dir.chdir(__dir__)

header_path = File.join("..", "lib", "hts", "libhts", "#{ARGV[0]}.rb")

attach_function_count = File.foreach(header_path).grep(/attach_function/).count
puts "count attach_function: #{attach_function_count}"

File.read(header_path)
    .scan(/attach_function.*\n?.*:.*(?=,)/)
    .each { |fn| puts fn.split(":").last }
