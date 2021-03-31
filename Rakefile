# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

task default: :test
Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
end

namespace :htslib do
  desc 'Building HTSlib'
  task :build do
    Dir.chdir('htslib') do
      system 'autoheader'
      system 'autoconf'
      system './configure'
      system 'make'
      FileUtils.mkdir_p('../vendor')
      require 'ffi'
      FileUtils.move(
        "libhts.#{FFI::Platform::LIBSUFFIX}",
        "../vendor/libhts.#{FFI::Platform::LIBSUFFIX}"
      )
    end
  end

  desc 'make clean'
  task :clean do
    Dir.chdir('htslib') do
      system 'make clean'
    end
  end
end

namespace :c2ffi do
  desc 'Generate metadata files (JSON format) using c2ffi'
  task :generate do
    require 'shellwords'
    FileUtils.mkdir_p('codegen/c2ffilogs')
    header_files = FileList['htslib/**/*.h']
    header_files.each do |file|
      basename = File.basename(file, '.h')
      cmd = 'c2ffi' \
            " -o codegen/#{basename}.json" \
            " -M codegen/#{basename}.c" \
            " #{file}" \
            " 2> codegen/c2ffilogs/#{basename}.log"
      system cmd
    end
  end

  desc 'Remove metadata files'
  task :remove do
    FileList['codegen/*.{json,c}', 'codegen/c2ffilogs/*.log'].each do |path|
      File.unlink(path) if File.exist?(path)
    end
  end
end
