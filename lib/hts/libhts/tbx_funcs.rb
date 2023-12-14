# frozen_string_literal: true

module HTS
  module LibHTS
    class << self
      def tbx_itr_destroy(iter)
        hts_itr_destroy(iter)
      end

      def tbx_itr_queryi(tbx, tid, beg, end_)
        hts_itr_query(tbx[:idx], tid, beg, end_, @ffi_functions[:tbx_readrec])
      end

      @@tbx_name2id = proc do |tbx, ss|
        LibHTS.tbx_name2id(tbx, ss)
      end

      def tbx_itr_querys(tbx, s)
        hts_itr_querys(tbx[:idx], s, @@tbx_name2id, tbx, @ffi_functions[:hts_itr_query],
                       @ffi_functions[:tbx_readrec])
      end

      def tbx_itr_next(htsfp, tbx, itr, r)
        hts_itr_next(hts_get_bgzfp(htsfp), itr, r, tbx)
      end

      def tbx_bgzf_itr_next(bgzfp, tbx, itr, r)
        hts_itr_next(bgzfp, itr, r, tbx)
      end
    end
  end
end
