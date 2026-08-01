# frozen_string_literal: true

module HTS
  class Bcf < Hts
    class HeaderRecord
      def initialize(native)
        raise TypeError, "Invalid argument" unless native.is_a?(Native::BcfHeaderRecordHandle)

        @native = native
      end

      def add_key(key) = @native.add_key(key)
      def set_value(index, value, quote: true) = @native.set_value(index, value, quote)
      def find_key(key) = @native.find_key(key)
      def to_s = @native.to_s

      private

      def native_handle = @native
      def initialize_copy(original) = (@native = original.__send__(:native_handle).duplicate)
    end
  end
end
