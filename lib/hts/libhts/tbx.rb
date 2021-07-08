# frozen_string_literal: true

module HTS
  module LibHTS
    attach_function \
      :tbx_name2id,
      [Tbx, :string],
      :int

    # Internal helper function used by tbx_itr_next()
    attach_function \
      :hts_get_bgzfp,
      [HtsFile],
      BGZF.by_ref

    attach_function \
      :tbx_readrec,
      [BGZF, :pointer, :pointer, :pointer, :pointer, :pointer],
      :int

    # Build an index of the lines in a BGZF-compressed file
    attach_function \
      :tbx_index,
      [BGZF, :int, TbxConf],
      Tbx.by_ref

    attach_function \
      :tbx_index_build,
      [:string, :int, TbxConf],
      :int

    attach_function \
      :tbx_index_build2,
      [:string, :string, :int, TbxConf],
      :int

    attach_function \
      :tbx_index_build3,
      [:string, :string, :int, :int, TbxConf],
      :int

    # Load or stream a .tbi or .csi index
    attach_function \
      :tbx_index_load,
      [:string],
      Tbx.by_ref

    # Load or stream a .tbi or .csi index
    attach_function \
      :tbx_index_load2,
      %i[string string],
      Tbx.by_ref

    # Load or stream a .tbi or .csi index
    attach_function \
      :tbx_index_load3,
      %i[string string int],
      Tbx.by_ref

    attach_function \
      :tbx_seqnames,
      [Tbx, :int],
      :pointer

    attach_function \
      :tbx_destroy,
      [Tbx],
      :void
  end
end
