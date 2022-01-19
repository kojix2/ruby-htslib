# frozen_string_literal: true

module HTS
  module LibHTS
    attach_function \
      :hts_tpool_init,
      [:int],
      HtsTpool.by_ref

    attach_function \
      :hts_tpool_size,
      [HtsTpool],
      :int

    # FIXME: struct
    HtsTpoolProcess = :pointer
    HtsTpoolResult  = :pointer

    attach_function \
      :hts_tpool_dispatch,
      [HtsTpool, HtsTpoolProcess, :pointer, :pointer],
      :int

    attach_function \
      :hts_tpool_dispatch2,
      [HtsTpool, HtsTpoolProcess, :pointer, :pointer, :int],
      :int

    attach_function \
      :hts_tpool_dispatch3,
      [HtsTpool, HtsTpoolProcess, :pointer, :pointer, :pointer, :pointer, :int],
      :int

    attach_function \
      :hts_tpool_wake_dispatch,
      [HtsTpoolProcess],
      :void

    attach_function \
      :hts_tpool_process_flush,
      [HtsTpoolProcess],
      :int

    attach_function \
      :hts_tpool_process_reset,
      [HtsTpoolProcess, :int],
      :int

    attach_function \
      :hts_tpool_process_qsize,
      [HtsTpoolProcess],
      :int

    attach_function \
      :hts_tpool_destroy,
      [HtsTpool],
      :void

    attach_function \
      :hts_tpool_kill,
      [HtsTpool],
      :void

    attach_function \
      :hts_tpool_next_result,
      [HtsTpoolProcess],
      HtsTpoolResult # .by_ref

    attach_function \
      :hts_tpool_next_result_wait,
      [HtsTpoolProcess],
      HtsTpoolResult # .by_ref

    attach_function \
      :hts_tpool_delete_result,
      [HtsTpoolResult, :int],
      :void

    attach_function \
      :hts_tpool_result_data,
      [HtsTpoolResult],
      :pointer

    attach_function \
      :hts_tpool_process_init,
      [HtsTpool, :int, :int],
      HtsTpoolProcess # .by_ref

    attach_function \
      :hts_tpool_process_destroy,
      [HtsTpoolProcess],
      :void

    attach_function \
      :hts_tpool_process_empty,
      [HtsTpoolProcess],
      :int

    attach_function \
      :hts_tpool_process_len,
      [HtsTpoolProcess],
      :int

    attach_function \
      :hts_tpool_process_sz,
      [HtsTpoolProcess],
      :int

    attach_function \
      :hts_tpool_process_shutdown,
      [HtsTpoolProcess],
      :void

    attach_function \
      :hts_tpool_process_is_shutdown,
      [HtsTpoolProcess],
      :int

    attach_function \
      :hts_tpool_process_attach,
      [HtsTpool, HtsTpoolProcess],
      :void

    attach_function \
      :hts_tpool_process_detach,
      [HtsTpool, HtsTpoolProcess],
      :void

    attach_function \
      :hts_tpool_process_ref_incr,
      [HtsTpoolProcess],
      :void

    attach_function \
      :hts_tpool_process_ref_decr,
      [HtsTpoolProcess],
      :void
  end
end
