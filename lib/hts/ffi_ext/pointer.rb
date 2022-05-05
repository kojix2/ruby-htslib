# frozen_string_literal: true

module FFI
  class Pointer
    def read_array_of_struct(type, length)
      ary = []
      size = type.size
      tmp = self
      length.times { |j|
        ary << type.new(tmp)
        tmp += size unless j == length-1 # avoid OOB
      }
      ary
    end unless method_defined?(:read_array_of_struct)
  end
end
