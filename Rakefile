# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/clean"
require "rake/extensiontask"
require "rake/testtask"

CLEAN.include(
  "coverage",
  "ext/htslib_native/coverage"
)

Rake::ExtensionTask.new("htslib_native_ext") do |ext|
  ext.ext_dir = "ext/htslib_native"
  ext.lib_dir = "lib"
end

# Test

task default: "test:local"
Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

Rake::Task[:test].enhance([:compile])

test_loader = 'Dir["test/**/*_test.rb"].sort.each { |path| require File.expand_path(path) }'
namespace :test do
  desc "Run tests that use local fixtures"
  task local: :compile do
    ruby "-Ilib", "-Itest", "-e", test_loader, "--", "--exclude", "/uri/"
  end

  desc "Run remote URI tests"
  task remote: :compile do
    ruby "-Ilib", "-Itest", "-e", test_loader, "--", "--name", "/uri/"
  end
end

# Release gem

# Prevent releasing the gem including htslib shared library.

task :check_shared_library_exist do
  unless Dir.glob("vendor/*.{so,dylib,dll}").empty?
    magenta = "\e[35m"
    clear = "\e[0m"
    abort "#{magenta}Shared library exists in the vendor directory.#{clear}"
  end
end

Rake::Task["release:guard_clean"].enhance(["check_shared_library_exist"])
