# frozen_string_literal: true

module HTS
  module LibHTS
    typedef :pointer, :cram_fd

    attach_function \
      :cram_fd_get_header,
      [:cram_fd],
      SamHdr.by_ref
    attach_function \
      :cram_fd_set_header,
      [:cram_fd, SamHdr.by_ref],
      :void
    attach_function \
      :cram_fd_get_version,
      [:cram_fd],
      :int

    attach_function \
      :cram_fd_set_version,
      %i[cram_fd int],
      :void

    attach_function \
      :cram_major_vers,
      [:cram_fd],
      :int

    attach_function \
      :cram_minor_vers,
      [:cram_fd],
      :int

    attach_function \
      :cram_fd_get_fp,
      [:cram_fd],
      HFile.by_ref

    attach_function \
      :cram_fd_set_fp,
      [:cram_fd, HFile],
      :void

    # attach_function \
    #  :cram_container_get_length,
    #  [CramContainer],
    #  :int32

    # attach_function \
    #   :cram_container_set_length,
    #   [CramContainer, :int32],
    #   :void

    # attach_function \
    #   :cram_container_get_num_blocks,
    #   [CramContainer],
    #   :int32

    # attach_function \
    #   :cram_container_set_num_blocks,
    #   [CramContainer, :int32],
    #   :void

    # attach_function \
    #   :cram_container_get_landmarks,
    #   [CramContainer, :int32],
    #   :pointer

    # attach_function \
    #   :cram_container_set_landmarks,
    #   [CramContainer, :Int32, :pointer],
    #   :void

    attach_function \
      :cram_container_is_empty,
      [:cram_fd],
      :int

    # attach_function \
    #   :cram_block_get_content_id,
    #   [CramBlock],
    #   :int32
    #
    # attach_function \
    #   :cram_block_get_comp_size,
    #   [CramBlock],
    #   :int32
    #
    # attach_function \
    #   :cram_block_get_uncomp_size,
    #   [CramBlock],
    #   :int32
    #
    # attach_function \
    #   :cram_block_get_crc32,
    #   [CramBlock],
    #   :int32
    #
    # attach_function \
    #   :cram_block_get_data,
    #   [CramBlock],
    #   :pointer
    #
    # attach_function \
    #   :cram_block_get_content_type,
    #   [CramBlock],
    #   CramContentType                # ?
    #
    # attach_function \
    #   :cram_block_set_content_id,
    #   [CramBlock, :int32],
    #   :void
    #
    # attach_function \
    #   :cram_block_set_comp_size,
    #   [CramBlock, :int32],
    #   :void
    #
    # attach_function \
    #   :cram_block_set_uncomp_size,
    #   [CramBlock, :int32],
    #   :void
    #
    # attach_function \
    #   :cram_block_set_crc32,
    #   [CramBlock, :int32],
    #   :void
    #
    # attach_function \
    #   :cram_block_set_data,
    #   [CramBlock, :pointer],
    #   :void
    #
    # attach_function \
    #   :cram_block_append,
    #   [CramBlock, :pointer, :int],
    #   :int
    #
    # attach_function \
    #   :cram_block_update_size,
    #   [CramBlock],
    #   :void
    #
    # attach_function \
    #   :cram_block_get_offset,
    #   [CramBlock],
    #   :size_t
    #
    # attach_function \
    #   :cram_block_set_offset,
    #   [CramBlock, :size_t],
    #   :void
    #
    # attach_function \
    #   :cram_block_size,
    #   [CramBlock],
    #   :uint32
    #
    # attach_function \
    #   :cram_transcode_rg,
    #   [:cram_fd, :cram_fd, CramContainer, :int, :pointer, :pointer],
    #   :int
    #
    # attach_function \
    #   :cram_copy_slice,
    #   [:cram_fd, :cram_fd, :int32],
    #   :int
    #
    # attach_function \
    #   :cram_new_block,
    #   [CramContentType, :int],
    #   CramBlock
    #
    # attach_function \
    #   :cram_read_block,
    #   [:cram_fd],
    #   CramBlock
    #
    # attach_function \
    #   :cram_write_block,
    #   [:cram_fd, CramBlock],
    #   :int
    #
    # attach_function \
    #   :cram_free_block,
    #   [CramBlock],
    #   :void
    #
    # attach_function \
    #   :cram_uncompress_block,
    #   [CramBlock],
    #   :int
    #
    # attach_function \
    #   :cram_compress_block,
    #   [:cram_fd, CramBlock, CramMetrics, :int, :int],
    #   :int
    #
    # attach_function \
    #   :cram_compress_block2,
    #   [:cram_fd, CramSlice, CramBlock, CramMetrics, :int, :int],
    #   :int
    #
    # attach_function \
    #   :cram_new_container,
    #   [:int, :int],
    #   CramContainer
    #
    # attach_function \
    #   :cram_free_container,
    #   [CramContainer],
    #   :void
    #
    # attach_function \
    #   :cram_read_container,
    #   [:cram_fd],
    #   CramContainer
    #
    # attach_function \
    #   :cram_write_container,
    #   [:cram_fd, CramContainer],
    #   :int
    #
    # attach_function \
    #   :cram_store_container,
    #   [:cram_fd, CramContainer, :string, :pointer],
    #   :int
    #
    # attach_function \
    #   :cram_container_size,
    #   [CramContainer],
    #   :int
    #
    attach_function \
      :cram_open,
      %i[string string],
      :cram_fd

    attach_function \
      :cram_dopen,
      %i[pointer string string],
      :cram_fd

    attach_function \
      :cram_close,
      [:cram_fd],
      :int

    attach_function \
      :cram_seek,
      %i[pointer off_t int],
      :int # FIXME: pointer should be :cram_fd

    attach_function \
      :cram_flush,
      [:cram_fd],
      :int

    attach_function \
      :cram_eof,
      [:cram_fd],
      :int

    # attach_function \
    #   :cram_set_option,
    #   [:cram_fd, HtsFmtOption, ...], # vararg!
    #   :int
    #
    # attach_function \
    #   :cram_set_voption,
    #   [:cram_fd, HtsFmtOption, VaList],
    #   :int
    #
    attach_function \
      :cram_set_header,
      [:cram_fd, SamHdr.by_ref],
      :int

    # attach_function \
    #   :cram_check_eof = :cram_check_EOF,
    #   [:cram_fd], :int
    #
    # attach_function \
    #   :cram_get_refs,
    #   [HtsFile],
    #   RefsT # what is RefsT
    #
  end
end
