# frozen_string_literal: true

module HTS
  module LibHTS

=begin

attach_function \
  :cram_fd_get_header,
  [CramFd],
  SamHdr.by_ref

attach_function \
  :cram_fd_set_header,
  [CramFd, SamHdr.by_ref],
  :void
  
attach_function \
  :cram_fd_get_version,
  [CramFd],
  :int

attach_function \
  :cram_fd_set_version,
  [CramFd, :int],
  :void

attach_function \
  :cram_major_vers,
  [CramFd],
  :int

attach_function \
  :cram_minor_vers,
  [CramFd],
  :int

attach_function \
  :cram_fd_get_fp,
  [CramFd],
  HFile.by_ref

attach_function \
  :cram_fd_set_fp,
  [CramFd, HFile],
  :void

attach_function \
  :cram_container_get_length,
  [CramContainer],
  :int32

attach_function \
  :cram_container_set_length,
  [CramContainer, :int32],
  :void

attach_function \
  :cram_container_get_num_blocks,
  [CramContainer],
  :int32

attach_function \
  :cram_container_set_num_blocks,
  [CramContainer, :int32],
  :void
  
attach_function \
  :cram_container_get_landmarks,
  [CramContainer, :int32],
  :pointer

attach_function \
  :cram_container_set_landmarks,
  [CramContainer, :Int32, :pointer],
  :void

attach_function \
  :cram_container_is_empty,
  [CramFd],
  :int

attach_function \
  :cram_block_get_content_id,
  [CramBlock],
  :int32

attach_function \
  :cram_block_get_comp_size,
  [CramBlock],
  :int32

attach_function \
  :cram_block_get_uncomp_size,
  [CramBlock],
  :int32

attach_function \
  :cram_block_get_crc32,
  [CramBlock],
  :int32

attach_function \
  :cram_block_get_data,
  [CramBlock],
  :pointer

attach_function \
  :cram_block_get_content_type,
  [CramBlock],
  CramContentType                # ?

attach_function \
  :cram_block_set_content_id,
  [CramBlock, :int32],
  :void
  
attach_function \
  :cram_block_set_comp_size,
  [CramBlock, :int32],
  :void

attach_function \
  :cram_block_set_uncomp_size,
  [CramBlock, :int32],
  :void
  
attach_function \
  :cram_block_set_crc32,
  [CramBlock, :int32],
  :void

attach_function \
  :cram_block_set_data,
  [CramBlock, :pointer],
  :void

attach_function \
  :cram_block_append,
  [CramBlock, :pointer, :int],
  :int

attach_function \
  :cram_block_update_size,
  [CramBlock],
  :void

attach_function \
  :cram_block_get_offset,
  [CramBlock],
  :size_t

attach_function \
  :cram_block_set_offset,
  [CramBlock, :size_t],
  :void

attach_function \
  :cram_block_size,
  [CramBlock],
  :uint32

attach_function \
  :cram_transcode_rg,
  [CramFd, CramFd, CramContainer, :int, :pointer, :pointer],
  :int

attach_function \
  :cram_copy_slice,
  [CramFd, CramFd, :int32],
  :int

attach_function \
  :cram_new_block,
  [CramContentType, :int],
  CramBlock

attach_function \
  :cram_read_block,
  [CramFd],
  CramBlock

attach_function \
  :cram_write_block,
  [CramFd, CramBlock],
  :int

attach_function \
  :cram_free_block,
  [CramBlock],
  :void
  
attach_function \
  :cram_uncompress_block,
  [CramBlock],
  :int

attach_function \
  :cram_compress_block,
  [CramFd, CramBlock, CramMetrics, :int, :int],
  :int

attach_function \
  :cram_compress_block2,
  [CramFd, CramSlice, CramBlock, CramMetrics, :int, :int],
  :int

attach_function \
  :cram_new_container,
  [:int, :int],
  CramContainer

attach_function \
  :cram_free_container,
  [CramContainer],
  :void

attach_function \
  :cram_read_container,
  [CramFd],
  CramContainer

attach_function \
  :cram_write_container,
  [CramFd, CramContainer],
  :int

attach_function \
  :cram_store_container,
  [CramFd, CramContainer, :string, :pointer],
  :int

attach_function \
  :cram_container_size,
  [CramContainer],
  :int

attach_function \
  :cram_open,
  [:string, :string],
  CramFd

attach_function \
  :cram_dopen,
  [:pointer, :string, :string],
  CramFd

attach_function \
  :cram_close,
  [CramFd],
  :int

=end

attach_function \
  :cram_seek,
  [:pointer, :off_t, :int], :int # FIXME pointer should be CramFd

=begin

attach_function \
  :cram_flush,
  [CramFd],
  :int

attach_function \
  :cram_eof,
  [CramFd],
  :int

attach_function \
  :cram_set_option,
  [CramFd, HtsFmtOption, ...], # vararg!
  :int

attach_function \
  :cram_set_voption,
  [CramFd, HtsFmtOption, VaList],
  :int

attach_function \
  :cram_set_header,
  [CramFd, SamHdr.by_ref],
  :int

attach_function \
  :cram_check_eof = :cram_check_EOF,
  [CramFd], :int

attach_function \
  :cram_get_refs,
  [HtsFile],
  RefsT # what is RefsT

=end
  end
end