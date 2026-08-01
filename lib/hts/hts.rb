# frozen_string_literal: true

require_relative "../htslib"

module HTS
  # Shared behavior for HTS-backed file classes. Native handles remain private
  # implementation details of the concrete classes.
  class Hts
    class << self
      private

      def define_getter(name)
        define_method(name) do
          check_closed
          position = tell
          values = map(&name)
          seek(position) if position
          values
        end
        alias_method "#{name}_array", name
      end

      def define_iterator(name)
        define_method("each_#{name}") do |&block|
          check_closed
          return to_enum(__method__) unless block

          each { |record| block.call(record.public_send(name)) }
          self
        end
      end
    end

    def initialize(*_args)
      raise TypeError, "Can't make instance of HTS abstract class"
    end

    private

    def check_closed
      raise IOError, "closed stream" if closed?
    end
  end
end
