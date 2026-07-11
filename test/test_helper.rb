# frozen_string_literal: true

require "simplecov"
SimpleCov.start
require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

class Fixtures
  def self.[](file_path)
    File.expand_path("fixtures/#{file_path}", __dir__)
  end
end

class Minitest::Test
  def silence_stderr
    stderr = $stderr.dup
    $stderr.reopen(File::NULL)
    yield
  ensure
    $stderr.flush
    $stderr.reopen(stderr) if stderr
    stderr&.close
  end
end
