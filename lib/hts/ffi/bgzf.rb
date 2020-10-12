# frozen_string_literal: true

# BGZF
module HTS
  module FFI
    # Open an existing file descriptor for reading or writing.
    attach_function \
      :bgzf_dopen,
      %i[int string],
      BGZF.by_ref

    # Open the specified file for reading or writing.
    attach_function \
      :bgzf_open,
      %i[string string],
      BGZF.by_ref

    # Open an existing hFILE stream for reading or writing.
    attach_function \
      :bgzf_hopen,
      %i[HFILE string],
      BGZF.by_ref

    # Close the BGZF and free all associated resources.
    attach_function \
      :bgzf_close,
      [:HFILE],
      :int

    # Read up to _length_ bytes from the file storing into _data_.
    attach_function \
      :bgzf_read,
      %i[HFILE pointer size_t],
      :ssize_t

    # Write _length_ bytes from _data_ to the file. If no I/O errors occur,
    # the complete _length_ bytes will be written (or queued for writing).
    attach_function \
      :bgzf_write,
      [BGZF, :pointer, :size_t],
      :ssize_t

    # Write _length_ bytes from _data_ to the file, the index will be used to
    # decide the amount of uncompressed data to be writen to each bgzip block.
    attach_function \
      :bgzf_block_write,
      [BGZF, :pointer, :size_t],
      :ssize_t

    # Returns the next byte in the file without consuming it.
    attach_function \
      :bgzf_peek,
      [BGZF],
      :int

    # Read up to _length_ bytes directly from the underlying stream without
    # decompressing.  Bypasses BGZF blocking, so must be used with care in
    # specialised circumstances only.
    attach_function \
      :bgzf_raw_read,
      [BGZF, :pointer, :size_t],
      :ssize_t

    # Write _length_ bytes directly to the underlying stream without
    # compressing.  Bypasses BGZF blocking, so must be used with care
    # in specialised circumstances only.
    attach_function \
      :bgzf_raw_write,
      [BGZF, :pointer, :size_t],
      :ssize_t

    # Write the data in the buffer to the file.
    attach_function \
      :bgzf_flush,
      [BGZF],
      :int

    # Set the file to read from the location specified by _pos_.
    attach_function \
      :bgzf_seek,
      [BGZF, :int64, :int],
      :int64

    # Check if the BGZF end-of-file (EOF) marker is present
    attach_function \
      :bgzf_check_EOF,
      [BGZF],
      :int

    # Return the file's compression format
    attach_function \
      :bgzf_compression,
      [BGZF],
      :int

    # Check if a file is in the BGZF format
    attach_function \
      :bgzf_is_bgzf,
      [:string],
      :int

    # Set the cache size. Only effective when compiled with -DBGZF_CACHE.
    attach_function \
      :bgzf_set_cache_size,
      [BGZF, :int],
      :void

    # Flush the file if the remaining buffer size is smaller than _size_
    attach_function \
      :bgzf_flush_try,
      [BGZF, :ssize_t],
      :int

    # Read one byte from a BGZF file. It is faster than bgzf_read()
    attach_function \
      :bgzf_getc,
      [BGZF],
      :int

    # Read one line from a BGZF file. It is faster than bgzf_getc()
    attach_function \
      :bgzf_getline,
      [BGZF, :int, Kstring],
      :int

    # Read the next BGZF block.
    attach_function \
      :bgzf_read_block,
      [BGZF],
      :int

    # Enable multi-threading (when compiled with -DBGZF_MT) via a shared
    # thread pool.
    attach_function \
      :bgzf_thread_pool,
      [BGZF, :pointer, :int],
      :int

    # Enable multi-threading (only effective when the library was compiled
    # with -DBGZF_MT)
    attach_function \
      :bgzf_mt,
      [BGZF, :int, :int],
      :int

    # Compress a single BGZF block.
    attach_function \
      :bgzf_compress,
      %i[pointer pointer pointer size_t int],
      :int

    # Position BGZF at the uncompressed offset
    attach_function \
      :bgzf_useek,
      [BGZF, :off_t, :int],
      :int

    # Position in uncompressed BGZF
    attach_function \
      :bgzf_utell,
      [BGZF],
      :off_t

    # Tell BGZF to build index while compressing.
    attach_function \
      :bgzf_index_build_init,
      [BGZF],
      :int

    # Load BGZF index
    attach_function \
      :bgzf_index_load,
      [BGZF, :string, :string],
      :int

    # Load BGZF index from an hFILE
    attach_function \
      :bgzf_index_load_hfile,
      [BGZF, :HFILE, :string],
      :int

    # Save BGZF index
    attach_function \
      :bgzf_index_dump,
      [BGZF, :string, :string],
      :int

    # Write a BGZF index to an hFILE
    attach_function \
      :bgzf_index_dump_hfile,
      [BGZF, :HFILE, :string],
      :int
  end
end
