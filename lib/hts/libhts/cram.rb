# frozen_string_literal: true

module HTS
  module LibHTS
    typedef :pointer, :cram_fd
    typedef :pointer, :cram_container
    typedef :pointer, :cram_block

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

    attach_function \
     :cram_container_get_length,
     [:cram_container],
     :int32

    attach_function \
      :cram_container_set_length,
      [:cram_container, :int32],
      :void

    attach_function \
      :cram_container_get_num_blocks,
      [:cram_container],
      :int32

    attach_function \
      :cram_container_set_num_blocks,
      [:cram_container, :int32],
      :void

    attach_function \
      :cram_container_get_landmarks,
      [:cram_container, :int32],
      :pointer

    attach_function \
      :cram_container_set_landmarks,
      [:cram_container, :int32, :pointer],
      :void

    attach_function \
      :cram_container_is_empty,
      [:cram_fd],
      :int

    attach_function \
      :cram_block_get_content_id,
      [:cram_block],
      :int32
    
    attach_function \
      :cram_block_get_comp_size,
      [:cram_block],
      :int32
    
    attach_function \
      :cram_block_get_uncomp_size,
      [:cram_block],
      :int32
    
    attach_function \
      :cram_block_get_crc32,
      [:cram_block],
      :int32
    
    attach_function \
      :cram_block_get_data,
      [:cram_block],
      :pointer
    
    # attach_function \
    #   :cram_block_get_content_type,
    #   [:cram_block],
    #   CramContentType                # ?
    
    attach_function \
      :cram_block_set_content_id,
      [:cram_block, :int32],
      :void
   
    attach_function \
      :cram_block_set_comp_size,
      [:cram_block, :int32],
      :void
    
    attach_function \
      :cram_block_set_uncomp_size,
      [:cram_block, :int32],
      :void
    
    attach_function \
      :cram_block_set_crc32,
      [:cram_block, :int32],
      :void
    
    attach_function \
      :cram_block_set_data,
      [:cram_block, :pointer],
      :void
    
    attach_function \
      :cram_block_append,
      [:cram_block, :pointer, :int],
      :int
    
    attach_function \
      :cram_block_update_size,
      [:cram_block],
      :void
    
    attach_function \
      :cram_block_get_offset,
      [:cram_block],
      :size_t
    
    attach_function \
      :cram_block_set_offset,
      [:cram_block, :size_t],
      :void
    
    attach_function \
      :cram_block_size,
      [:cram_block],
      :uint32
    
    attach_function \
      :cram_transcode_rg,
      [:cram_fd, :cram_fd, :cram_container, :int, :pointer, :pointer],
      :int
    
    attach_function \
       :cram_copy_slice,
      [:cram_fd, :cram_fd, :int32],
      :int
    
    # attach_function \
    #  :cram_new_block,
    #   [CramContentType, :int],
    #   :cram_block
    
    attach_function \
      :cram_read_block,
      [:cram_fd],
      :cram_block
    
    attach_function \
      :cram_write_block,
      [:cram_fd, :cram_block],
      :int
    
    attach_function \
      :cram_free_block,
      [:cram_block],
      :void
    
    attach_function \
      :cram_uncompress_block,
      [:cram_block],
      :int
    
    # attach_function \
    #   :cram_compress_block,
    #   [:cram_fd, :cram_block, CramMetrics, :int, :int],
    #   :int
    #
    # attach_function \
    #   :cram_compress_block2,
    #   [:cram_fd, CramSlice, :cram_block, CramMetrics, :int, :int],
    #   :int
    
    attach_function \
      :cram_new_container,
      [:int, :int],
      :cram_container
    
    attach_function \
      :cram_free_container,
      [:cram_container],
      :void
    
    attach_function \
      :cram_read_container,
      [:cram_fd],
      :cram_container
    
    attach_function \
      :cram_write_container,
      [:cram_fd, :cram_container],
      :int
    
    attach_function \
      :cram_store_container,
      [:cram_fd, :cram_container, :string, :pointer],
      :int
    
    attach_function \
      :cram_container_size,
      [:cram_container],
      :int
    
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
