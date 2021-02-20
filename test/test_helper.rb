# frozen_string_literal: true

require 'simplecov'
SimpleCov.start
require 'bundler/setup'
Bundler.require(:default)
require 'minitest/autorun'
require 'minitest/pride'

class Fixtures
  def self.[](fname)
    File.expand_path("fixtures/#{fname}", __dir__)
  end
end
