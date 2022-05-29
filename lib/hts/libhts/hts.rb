# frozen_string_literal: true

module HTS
  module LibHTS
    # hts_expand
    # hts_expand3
    # hts_resize

    # Sets the selected log level.
    attach_function \
      :hts_set_log_level,
      [HtsLogLevel],
      :void

    # Gets the selected log level.
    attach_function \
      :hts_get_log_level,
      [],
      HtsLogLevel

    attach_function \
      :hts_lib_shutdown,
      [],
      :void

    attach_function \
      :hts_free,
      [:pointer],
      :void

    # Parses arg and appends it to the option list.
    attach_function \
      :hts_opt_add,
      %i[pointer string],
      :int

    # Applies an hts_opt option list to a given htsFile.
    attach_function \
      :hts_opt_apply,
      [HtsFile, HtsOpt],
      :int

    # Frees an hts_opt list.
    attach_function \
      :hts_opt_free,
      [HtsOpt],
      :void

    # Accepts a string file format (sam, bam, cram, vcf, bam)
    attach_function \
      :hts_parse_format,
      [HtsFormat, :string],
      :int

    # Tokenise options as (key(=value)?,)*(key(=value)?)?
    attach_function \
      :hts_parse_opt_list,
      [HtsFormat, :string],
      :int

    # Get the htslib version number
    attach_function \
      :hts_version,
      [],
      :string

    # Introspection on the features enabled in htslib
    attach_function \
      :hts_features,
      [],
      :uint

    attach_function \
      :hts_test_feature,
      [:uint],
      :string

    # Introspection on the features enabled in htslib, string form
    attach_function \
      :hts_feature_string,
      [],
      :string

    # Determine format by peeking at the start of a file
    attach_function \
      :hts_detect_format,
      [HFile, HtsFormat],
      :int

    # Determine format primarily by peeking at the start of a file
    attach_function \
      :hts_detect_format2,
      [HFile, :string, HtsFormat],
      :int

    # Get a human-readable description of the file format
    attach_function \
      :hts_format_description,
      [HtsFormat],
      :string

    # Open a sequence data (SAM/BAM/CRAM) or variant data (VCF/BCF)
    # or possibly-compressed textual line-orientated file
    attach_function \
      :hts_open,
      %i[string string],
      HtsFile.by_ref

    # Open a SAM/BAM/CRAM/VCF/BCF/etc file
    attach_function \
      :hts_open_format,
      [:string, :string, HtsFormat],
      HtsFile.by_ref

    # Open an existing stream as a SAM/BAM/CRAM/VCF/BCF/etc file
    attach_function \
      :hts_hopen,
      [HFile, :string, :string],
      HtsFile.by_ref

    # For output streams, flush any buffered data
    attach_function \
      :hts_flush,
      [HtsFile],
      :int

    # Close a file handle, flushing buffered data for output streams
    attach_function \
      :hts_close,
      [HtsFile],
      :int

    # Returns the file's format information
    attach_function \
      :hts_get_format,
      [HtsFile],
      HtsFormat.by_ref

    # Returns a string containing the file format extension.
    attach_function \
      :hts_format_file_extension,
      [HtsFormat],
      :string

    # Sets a specified CRAM option on the open file handle.
    attach_function \
      :hts_set_opt,
      [HtsFile, HtsFmtOption, :varargs],
      :int

    # Read a line (and its \n or \r\n terminator) from a file
    attach_function \
      :hts_getline,
      [HtsFile, :int, KString],
      :int

    attach_function \
      :hts_readlines,
      %i[string pointer],
      :pointer

    # Parse comma-separated list or read list from a file
    attach_function \
      :hts_readlist,
      %i[string int pointer],
      :pointer

    # Create extra threads to aid compress/decompression for this file
    attach_function \
      :hts_set_threads,
      [HtsFile, :int],
      :int

    # Create extra threads to aid compress/decompression for this file
    attach_function \
      :hts_set_thread_pool,
      [HtsFile, HtsTpool],
      :int

    # Adds a cache of decompressed blocks, potentially speeding up seeks.
    attach_function \
      :hts_set_cache_size,
      [HtsFile, :int],
      :void

    # Set .fai filename for a file opened for reading
    attach_function \
      :hts_set_fai_filename,
      [HtsFile, :string],
      :int

    # Sets a filter expression
    attach_function \
      :hts_set_filter_expression,
      [HtsFile, :string],
      :int

    # Determine whether a given htsFile contains a valid EOF block
    attach_function \
      :hts_check_EOF,
      [HtsFile],
      :int

    # hts_pair_pos_t
    # hts_pair64_t
    # hts_pair4_max_t
    # hts_reglist_t
    # hts_readrec_func
    # hts_seek_func
    # hts_tell_func

    # Create a BAI/CSI/TBI type index structure
    attach_function \
      :hts_idx_init,
      %i[int int uint64 int int],
      :pointer

    # Free a BAI/CSI/TBI type index
    attach_function \
      :hts_idx_destroy,
      [HtsIdx],
      :void

    # Push an index entry
    attach_function \
      :hts_idx_push,
      [HtsIdx, :int, :int64, :int64, :uint64, :int],
      :int

    # Finish building an index
    attach_function \
      :hts_idx_finish,
      [HtsIdx, :uint64],
      :int

    # Returns index format
    attach_function \
      :hts_idx_fmt,
      [HtsIdx],
      :int

    # Add name to TBI index meta-data
    attach_function \
      :hts_idx_tbi_name,
      [HtsIdx, :int, :string],
      :int

    # Save an index to a file
    attach_function \
      :hts_idx_save,
      [HtsIdx, :string, :int],
      :int

    # Save an index to a specific file
    attach_function \
      :hts_idx_save_as,
      [HtsIdx, :string, :string, :int],
      :int

    # Load an index file
    attach_function \
      :hts_idx_load,
      %i[string int],
      HtsIdx.by_ref

    # Load a specific index file
    attach_function \
      :hts_idx_load2,
      %i[string string],
      HtsIdx.by_ref

    # Load a specific index file
    attach_function \
      :hts_idx_load3,
      %i[string string int int],
      HtsIdx.by_ref

    # Get extra index meta-data
    attach_function \
      :hts_idx_get_meta,
      [HtsIdx, :pointer],
      :uint8

    # Set extra index meta-data
    attach_function \
      :hts_idx_set_meta,
      [HtsIdx, :uint32, :pointer, :int],
      :int

    # Get number of mapped and unmapped reads from an index
    attach_function \
      :hts_idx_get_stat,
      [HtsIdx, :int, :pointer, :pointer],
      :int

    # Return the number of unplaced reads from an index
    attach_function \
      :hts_idx_get_n_no_coor,
      [HtsIdx],
      :uint64

    # Return a list of target names from an index
    attach_function \
      :hts_idx_seqnames,
      [HtsIdx, :pointer, :pointer, :pointer],
      :pointer

    #  Return the number of targets from an index
    attach_function \
      :hts_idx_nseq,
      [HtsIdx],
      :int

    # Parse a numeric string
    attach_function \
      :hts_parse_decimal,
      %i[string pointer int],
      :long_long

    callback :hts_name2id_f, %i[pointer string], :int

    # Parse a "CHR:START-END"-style region string
    attach_function \
      :hts_parse_reg64,
      %i[string pointer pointer],
      :string

    # Parse a "CHR:START-END"-style region string
    attach_function \
      :hts_parse_reg,
      %i[string pointer pointer],
      :string

    # Parse a "CHR:START-END"-style region string
    attach_function \
      :hts_parse_region,
      %i[string pointer pointer pointer hts_name2id_f pointer int],
      :string

    # Create a single-region iterator
    attach_function \
      :hts_itr_query,
      [HtsIdx, :int, :hts_pos_t, :hts_pos_t, :pointer],
      HtsItr.by_ref

    # Free an iterator
    attach_function \
      :hts_itr_destroy,
      [HtsItr],
      :void

    # Create a single-region iterator from a text region specification
    attach_function \
      :hts_itr_querys,
      [HtsIdx, :string, :hts_name2id_f, :pointer, :pointer, :pointer],
      HtsItr.by_ref

    # Return the next record from an iterator
    attach_function \
      :hts_itr_next,
      [BGZF, HtsItr, :pointer, :pointer],
      :int

    attach_function \
      :hts_itr_multi_bam,
      [HtsIdx, HtsItr],
      :int

    attach_function \
      :hts_itr_multi_cram,
      [HtsIdx, HtsItr],
      :int

    # Create a multi-region iterator from a region list
    attach_function \
      :hts_itr_regions,
      [HtsIdx,
       :pointer, # hts_reglist_t *
       :int,
       :hts_name2id_f,
       :pointer,
       :pointer, # hts_itr_multi_query_func
       :pointer, # hts_readrec_func
       :pointer, # hts_seek_func
       :pointer  # hts_tell_func
      ],
      HtsItr.by_ref

    # Return the next record from an iterator
    attach_function \
      :hts_itr_multi_next,
      [HtsFile, HtsItr, :pointer],
      :int

    # Create a region list from a char array
    attach_function \
      :hts_reglist_create,
      %i[pointer int pointer pointer hts_name2id_f],
      HtsReglist.by_ref

    # Free a region list
    attach_function \
      :hts_reglist_free,
      [HtsReglist, :int],
      :void

    # Deprecated
    # Convenience function to determine file type
    # attach_function \
    #   :hts_file_type,
    #   [:string],
    #   :int

    attach_function \
      :errmod_init,
      [:double],
      :pointer

    attach_function \
      :errmod_destroy,
      [:pointer],
      :void

    attach_function \
      :errmod_cal,
      %i[pointer int int pointer pointer],
      :int

    # Perform probabilistic banded glocal alignment
    attach_function \
      :probaln_glocal,
      %i[pointer int pointer int pointer pointer pointer pointer],
      :int

    # Initialises an MD5 context.
    attach_function \
      :hts_md5_init,
      [],
      :pointer # hts_md5_context

    # Updates the context with the MD5 of the data.
    attach_function \
      :hts_md5_update,
      %i[pointer pointer ulong],
      :void

    # Computes the final 128-bit MD5 hash from the given context
    attach_function \
      :hts_md5_final,
      %i[pointer pointer], # unsinged char
      :void

    #  Resets an md5_context to the initial state, as returned by hts_md5_init().
    attach_function \
      :hts_md5_reset,
      [:pointer],
      :void

    # Converts a 128-bit MD5 hash into a 33-byte nul-termninated by string.
    attach_function \
      :hts_md5_hex,
      %i[string pointer],
      :void

    #  Deallocates any memory allocated by hts_md5_init.
    attach_function \
      :hts_md5_destroy,
      [:pointer],
      :void
  end
end
