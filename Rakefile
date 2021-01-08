# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :htslib do
  desc 'Building HTSlib'
  task :compile do
    Dir.chdir('htslib') do
      system 'autoheader'
      system 'autoconf'
      system './configure'
      system 'make'
      FileUtils.mkdir_p('../vendor')
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
