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
    header_files = FileList['htslib/**/*/*.h']
    header_files.each do |file|
      system "c2ffi #{file}" \
             " -o codegen/native_functions/#{File.basename(file, '.h')}.json"
    end
  end

  desc 'Remove metadata files'
  task :remove do
    FileList['codegen/native_functions/*.json'].each do |path|
      File.unlink(path) if File.exist?(path)
    end
  end
end
