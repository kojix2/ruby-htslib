# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "etc" # make -j #{Etc.nprocessors}

task default: :test
Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

namespace :htslib do
  desc "Building HTSlib"
  task :build do
    Dir.chdir("htslib") do
      unless File.exist? "htscodecs/README.md"
        puts "Missing git submodules"
        puts "Use `git submodule update --init --recursive`"
        exit 1
      end
      sh "autoreconf -i"
      sh "./configure"
      sh "make -j #{Etc.nprocessors}"
      FileUtils.mkdir_p("../vendor")
      require "ffi"
      FileUtils.move(
        "libhts.#{FFI::Platform::LIBSUFFIX}",
        "../vendor/libhts.#{FFI::Platform::LIBSUFFIX}"
      )
    end
  end

  desc "make clean"
  task :clean do
    Dir.chdir("htslib") do
      sh "make clean"
    end
  end
end
