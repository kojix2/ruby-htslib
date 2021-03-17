# frozen_string_literal: true

module HTS
  module FFI
    extend ::FFI::Library

    begin
      ffi_lib HTS.ffi_lib
    rescue LoadError => e
      raise LoadError, "#{e}\nCould not find #{HTS.ffi_lib}"
    end

    def self.attach_function(*)
      super
    rescue ::FFI::NotFoundError => e
      warn e.message
    end
  end
end

module FFI
  class Struct
    class << self
      def union_layout(*args)
        Class.new(FFI::Union) { layout(*args) }
      end

      def struct_layout(*args)
        Class.new(FFI::Struct) { layout(*args) }
      end
    end
  end

  class BitStruct < Struct
    class << self
      module BitFieldsModule
        def [](name)
          bit_fields = self.class.bit_fields_hash_table
          parent, start, width = bit_fields[name]
          if parent
            (super(parent) >> start) & ((1 << width) - 1)
          else
            super(name)
          end
        end
      end
      private_constant :BitFieldsModule

      attr_reader :bit_fields_hash_table

      def bitfields(*args)
        unless instance_variable_defined?(:@bit_fields_hash_table)
          @bit_fields_hash_table = {}
          prepend BitFieldsModule
        end

        parent = args.shift
        labels = []
        widths = []
        args.each_slice(2) do |l, w|
          labels << l
          widths << w
        end
        starts = widths.inject([0]) do |result, w|
          result << (result.last + w)
        end
        labels.zip(starts, widths).each do |l, s, w|
          @bit_fields_hash_table[l] = [parent, s, w]
        end
      end
    end
  end
end

require_relative 'ffi/constants'

# alphabetical order
require_relative 'ffi/bgzf'
require_relative 'ffi/faidx'
require_relative 'ffi/hfile'
require_relative 'ffi/hts'
require_relative 'ffi/sam'
require_relative 'ffi/kfunc'
require_relative 'ffi/tbx'
require_relative 'ffi/vcf'
