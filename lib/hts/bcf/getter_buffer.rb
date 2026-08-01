# frozen_string_literal: true

module HTS
  class Bcf < Hts
    # Reusable storage for HTSlib getters taking a void **dst and int *ndst.
    #
    # HTSlib owns the reallocation policy, while this object owns the resulting
    # allocation. A buffer must never be shared between records or accessors.
    class GetterBuffer
      attr_reader :dst_pointer, :capacity_pointer, :generation

      def initialize
        @dst_pointer = FFI::MemoryPointer.new(:pointer)
        @dst_pointer.write_pointer(FFI::Pointer::NULL)
        @capacity_pointer = FFI::MemoryPointer.new(:int)
        @capacity_pointer.write_int(0)
        @generation = 0

        ObjectSpace.define_finalizer(self, self.class.send(:finalizer, @dst_pointer))
      end

      def pointer
        @dst_pointer.read_pointer
      end

      def advance!
        @generation += 1
      end

      def self.finalizer(dst_pointer)
        proc do
          pointer = dst_pointer.read_pointer
          LibHTS.hts_free(pointer) unless pointer.null?
          dst_pointer.write_pointer(FFI::Pointer::NULL)
        end
      end
      private_class_method :finalizer
    end
  end
end
