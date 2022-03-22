# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

require_relative "../htslib"

module HTS
  class Tabix
    class << self
      alias open new
    end
    def initialize
      # IO like API
      if block_given?
        begin
          yield self
        ensure
          close
        end
      end
    end

    def build; end

    def sequences; end

    # def __call__\
  end
end
