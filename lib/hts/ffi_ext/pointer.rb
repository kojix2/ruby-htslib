# frozen_string_literal: true

module FFI
  class Pointer
    unless method_defined?(:read_array_of_struct)
      def read_array_of_struct(type, length)
        ary = []
        size = type.size
        tmp = self
        length.times do |j|
          ary << type.new(tmp)
          tmp += size unless j == length - 1 # avoid OOB
        end
        ary
      end
    end
  end
end
