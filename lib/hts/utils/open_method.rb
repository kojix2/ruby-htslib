# frozen_string_literal: true

module HTS
  module Utils
    module OpenMethod
      def open(path)
        object = new(path)
        if block_given?
          yield(object)
          object.close
        else
          object
        end
      end
    end
  end
end
