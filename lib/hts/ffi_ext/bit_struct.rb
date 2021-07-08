# frozen_string_literal: true

module FFI
  # Struct that support bit fields.
  # Currently readonly.
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

      # @example Bcf1
      #   class Bcf1 < FFI::BitStruct
      #     layout \
      #       :pos,            :hts_pos_t,
      #       :rlen,           :hts_pos_t,
      #       :rid,            :int32_t,
      #       :qual,           :float,
      #       :_n_info_allele, :uint32_t,
      #       :_n_fmt_sample,  :uint32_t,
      #       :shared,         KString,
      #       :indiv,          KString,
      #       :d,              BcfDec,
      #       :max_unpack,     :int,
      #       :unpacked,       :int,
      #       :unpack_size,    [:int, 3],
      #       :errcode,        :int
      #
      #     bit_fields :_n_info_allele,
      #                :n_info,   16,
      #                :n_allele, 16
      #
      #     bit_fields :_n_fmt_sample,
      #                :n_fmt,    8,
      #                :n_sample, 24
      #   end

      def bit_fields(*args)
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
