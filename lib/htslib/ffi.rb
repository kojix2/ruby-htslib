# frozen_string_literal: true

module HTSlib
  module Native
    extend FFI::Library
    begin
      ffi_lib HTSlib.ffi_lib
    rescue LoadError => e
      raise LoadError, 'Could not find HTSlib.so'
    end

    # kstring

    class Kstring < FFI::Struct
      layout :l, :size_t,
             :m, :size_t,
             :s, :string
    end

    # hfile

    class HFILE < FFI::Struct
      layout :buffer, :string,
             :begin, :string,
             :end, :string,
             :limit, :string,
             :backend, :pointer, # FIXME
             :offset, :off_t,
             :fuga, :uint, # FIXME
             :has_errno, :int
    end

    attach_function :hdopen, %i[int string], HFILE.by_ref
    attach_function :hisremote, [:string], :int
    # attach_function :haddextension, [Kstring.by_ref, :string, :int, :string], :string
    attach_function :hclose, [HFILE.by_ref], :int
    attach_function :hclose_abruptly, [HFILE.by_ref], :void
    attach_function :hseek, [HFILE.by_ref, :off_t, :int], :off_t
    attach_function :hgetdelim, [:string, :size_t, :int, HFILE.by_ref], :ssize_t
    attach_function :hgets, [:string, :int, HFILE.by_ref], :string
    attach_function :hpeek, [HFILE.by_ref, :pointer, :size_t], :ssize_t
    attach_function :hflush, [HFILE.by_ref], :int
    attach_function :hfile_mem_get_buffer, [HFILE.by_ref, :pointer], :string
    attach_function :hfile_mem_steal_buffer, [HFILE.by_ref, :pointer], :string

    # BGZF

    class BGZF < FFI::Struct
      layout :piyo, :uint, # FIXME
             :cache_size, :int,
             :block_length, :int,
             :block_clength, :int,
             :block_offset, :int,
             :block_address, :int64,
             :uncompressed_address, :int64,
             :uncompressed_block, :pointer,
             :compressed_block, :pointer,
             :cache, :pointer,
             :fp, HFILE.ptr,
             :mt, :pointer,
             :idx, :pointer,
             :idx_build_otf, :int,
             :gz_stream, :pointer,
             :seeked, :int64
    end

    attach_function :bgzf_dopen, %i[int string], BGZF.by_ref
    attach_function :bgzf_open, %i[string string], BGZF.by_ref
    attach_function :bgzf_hopen, [HFILE.by_ref, :string], BGZF.by_ref
    attach_function :bgzf_close, [HFILE.by_ref], :int
    attach_function :bgzf_read, [HFILE.by_ref, :pointer, :size_t], :size_t
    attach_function :bgzf_write, [BGZF.by_ref, :pointer, :size_t], :ssize_t
    # attach_function :bgzf_peek, [BGZF.by_ref], :int
    attach_function :bgzf_raw_read, [BGZF.by_ref, :pointer, :size_t], :ssize_t
    attach_function :bgzf_raw_write, [BGZF.by_ref, :pointer, :size_t], :ssize_t
    attach_function :bgzf_flush, [BGZF.by_ref], :int
    attach_function :bgzf_seek, [BGZF.by_ref, :int64, :int], :int64
    attach_function :bgzf_check_EOF, [BGZF.by_ref], :int
    attach_function :bgzf_compression, [BGZF.by_ref], :int
    attach_function :bgzf_is_bgzf, [:string], :int
    attach_function :bgzf_set_cache_size, [BGZF.by_ref, :int], :void
    attach_function :bgzf_flush_try, [BGZF.by_ref, :ssize_t], :int
    attach_function :bgzf_getc, [BGZF.by_ref], :int
    attach_function :bgzf_getline, [BGZF.by_ref, :int, Kstring.by_ref], :int
    attach_function :bgzf_read_block, [BGZF.by_ref], :int
    attach_function :bgzf_mt, [BGZF.by_ref, :int, :int], :int
    attach_function :bgzf_compress, %i[pointer pointer pointer size_t int], :int
    attach_function :bgzf_useek, [BGZF.by_ref, :off_t, :int], :int
    attach_function :bgzf_utell, [BGZF.by_ref], :off_t
    attach_function :bgzf_index_build_init, [BGZF.by_ref], :int
    attach_function :bgzf_index_load, [BGZF.by_ref, :string, :string], :int
    attach_function :bgzf_index_load_hfile, [BGZF.by_ref, HFILE.by_ref, :string], :int
    attach_function :bgzf_index_dump, [BGZF.by_ref, :string, :string], :int
    attach_function :bgzf_index_dump_hfile, [BGZF.by_ref, HFILE.by_ref, :string], :int

    # hts

    # Should this start with small character? For example, htsFromatCategory
    HtsFormatCategory = enum(:unknown_category, :sequence_data, :variant_data,
                             :index_file, :region_list, :category_maximum)
    HtsExactFormat = enum(:unknown_format, :binary_format, :text_format, :sam,
                          :bam, :bai, :cram, :crai, :vcf, :bcf, :csi, :gzi, :tbi,
                          :bed, :format_maximum)
    HtsCompression = enum(:no_compression, :gzip, :bgzf, :custom,
                          :compression_maximum)
    HtsFmtOption = enum( # CRAM specific
      :CRAM_OPT_DECODE_MD,
      :CRAM_OPT_PREFIX,
      :CRAM_OPT_VERBOSITY,  # obsolete, use hts_set_log_level() instead
      :CRAM_OPT_SEQS_PER_SLICE,
      :CRAM_OPT_SLICES_PER_CONTAINER,
      :CRAM_OPT_RANGE,
      :CRAM_OPT_VERSION,    # rename to :CRAM_version?
      :CRAM_OPT_EMBED_REF,
      :CRAM_OPT_IGNORE_MD5,
      :CRAM_OPT_REFERENCE,  # make general
      :CRAM_OPT_MULTI_SEQ_PER_SLICE,
      :CRAM_OPT_NO_REF,
      :CRAM_OPT_USE_BZIP2,
      :CRAM_OPT_SHARED_REF,
      :CRAM_OPT_NTHREADS,   # deprecated, use HTS_OPT_NTHREADS
      :CRAM_OPT_THREAD_POOL, # make general
      :CRAM_OPT_USE_LZMA,
      :CRAM_OPT_USE_RANS,
      :CRAM_OPT_REQUIRED_FIELDS,
      :CRAM_OPT_LOSSY_NAMES,
      :CRAM_OPT_BASES_PER_SLICE,
      :CRAM_OPT_STORE_MD,
      :CRAM_OPT_STORE_NM,
      # General purpose
      :HTS_OPT_COMPRESSION_LEVEL, 100,
      :HTS_OPT_NTHREADS,
      :HTS_OPT_THREAD_POOL,
      :HTS_OPT_CACHE_SIZE,
      :HTS_OPT_BLOCK_SIZE
    )

    # Should this be located at HTSlib Module? not HTSlib::Native?
    class HtsFormat < FFI::Struct
      layout :category, HtsFormatCategory,
             :format, HtsExactFormat,
             :version, Class.new(FFI::Struct) {
               layout :major, :short,
                      :minor, :short
             }.ptr,
             :compression, HtsCompression,
             :compression_lebel, :short,
             :specific, :pointer
    end

    class HtsFile < FFI::Struct
      layout :foo, :uint32, # FIXME
             :lineno, :int64,
             :line, Kstring,
             :fn, :string,
             :fn_aux, :string,
             :fp, :pointer,
             :format, HtsFormat
    end

    class HtsThreadPool < FFI::Struct
      layout :pool, :pointer,
             :qsize, :int
    end

    class HtsOpt < FFI::Struct
      layout :arg, :string,
             :opt, HtsFmtOption,
             :val, Class.new(FFI::Union) {
               layout :i, :int,
                      :s, :string
             },
             :next, HtsOpt.ptr
    end

    class HtsIdx < FFI::Struct
      layout :fmt, :int,
             :min_shift, :int,
             :n_lvls, :int,
             :n_bins, :int,
             :l_meta, :uint32,
             :n, :int32,
             :m, :int32,
             :n_no_coor, :uint64,
             :bidx, :pointer,
             :lidx, :pointer,
             :meta, :pointer,
             :tbi_n, :int,
             :last_tbi_tid, :int,
             :z, Class.new(FFI::Struct) {
                   layout :last_bin, :uint32,
                          :save_bin, :uint32,
                          :last_coor, :pointer,
                          :last_tid, :int,
                          :save_tid, :int,
                          :finished, :int,
                          :last_off, :uint64,
                          :save_off, :uint64,
                          :off_beg, :uint64,
                          :off_end, :uint64,
                          :n_mapped, :uint64,
                          :n_unmapped, :uint64
                 }
    end

    class HtsItr < FFI::Struct
      layout :foo, :uint32, # FIXME
             :tid, :int,
             :n_off, :int,
             :i, :int,
             :n_reg, :int,
             :beg, :int64,
             :end, :int64,
             :reg_list, :pointer,
             :curr_tid, :int,
             :curr_reg, :int,
             :curr_intv, :int,
             :curr_beg, :int64,
             :curr_end, :int64,
             :curr_off, :uint64,
             :nocoor_off, :uint64,
             :off, :pointer,
             :readrec, :pointer,
             :seek, :pointer,
             :tell, :pointer,
             :bins, Class.new(FFI::Struct) {
                      layout :n, :int,
                             :m, :int,
                             :a, :pointer
                    }
    end

    # attach_function :hts_free, [:pointer], :void
    # attach_function :hts_opt_add
    attach_function :hts_opt_apply, [HtsFile.by_ref, HtsOpt.by_ref], :int
    attach_function :hts_opt_free, [HtsOpt.by_ref], :void
    attach_function :hts_parse_format, [HtsFormat.by_ref, :string], :int
    attach_function :hts_parse_opt_list, [HtsFormat.by_ref, :string], :int
    attach_function :hts_version, %i[], :string
    attach_function :hts_detect_format, [HFILE.by_ref, HtsFormat.by_ref], :int
    attach_function :hts_format_description, [HtsFormat.by_ref], :string
    attach_function :hts_open, %i[string string], HtsFile.by_ref
    attach_function :hts_open_format, [:string, :string, HtsFormat.by_ref], HtsFile.by_ref
    attach_function :hts_hopen, [HFILE.by_ref, :string, :string], HtsFile.by_ref
    attach_function :hts_close, [HtsFile.by_ref], :int
    attach_function :hts_get_format, [HtsFile.by_ref], HtsFormat.by_ref
    attach_function :hts_format_file_extension, [HtsFormat.by_ref], :string
    # attach_function :hts_set_opt
    attach_function :hts_getline, [HtsFile.by_ref, :int, Kstring.by_ref], :int
    attach_function :hts_readlines, %i[string pointer], :pointer
    attach_function :hts_readlist, %i[string int pointer], :pointer

    attach_function :hts_set_threads, [HtsFile.by_ref, :int], :int
    attach_function :hts_set_thread_pool, [HtsFile.by_ref, HtsThreadPool.by_ref], :int
    attach_function :hts_set_cache_size, [HtsFile.by_ref, :int], :void
    attach_function :hts_set_fai_filename, [HtsFile.by_ref, :string], :int
    attach_function :hts_check_EOF, [HtsFile.by_ref], :int

    # typedef int64_t hts_pos_t;

    attach_function :hts_idx_init, %i[int int uint64 int int], :pointer
    attach_function :hts_idx_destroy, [HtsIdx.by_ref], :void

    attach_function :hts_idx_push, [HtsIdx.by_ref, :int, :int64, :int64, :uint64, :int], :int
    attach_function :hts_idx_finish, [HtsIdx.by_ref, :uint64], :int
    # attach_function :hts_idx_fmt, [HtsIdx.by_ref], :int
    # attach_function :hts_idx_tbi_name, [HtsIdx.by_ref, :int, :string], :int
    attach_function :hts_idx_save, [HtsIdx.by_ref, :string, :int], :int
    attach_function :hts_idx_save_as, [HtsIdx.by_ref, :string, :string, :int], :int
    attach_function :hts_idx_load, %i[string int], HtsIdx.by_ref
    attach_function :hts_idx_load2, %i[string string], HtsIdx.by_ref
    # attach_function :hts_idx_load3, %i[string string int int], HtsIdx.by_ref
    attach_function :hts_idx_get_meta, [HtsIdx.by_ref, :pointer], :uint8
    attach_function :hts_idx_set_meta, [HtsIdx.by_ref, :uint32, :pointer, :int], :int
    attach_function :hts_idx_get_stat, [HtsIdx.by_ref, :int, :pointer, :pointer], :int
    attach_function :hts_idx_get_n_no_coor, [HtsIdx.by_ref], :uint64
    attach_function :hts_parse_decimal, %i[string pointer int], :long_long
    # attach_function :hts_parse_reg64, %i[string pointer pointer], :string
    attach_function :hts_parse_reg, %i[string pointer pointer], :string
    # attach_function :hts_parse_region, %i[string pointer pointer pointer pointer int]
    # attach_function :hts_itr_query
    attach_function :hts_itr_destroy, [HtsItr.by_ref], :void
    # attach_function :hts_itr_querys
    attach_function :hts_itr_next, [BGZF.by_ref, HtsItr.by_ref, :pointer, :pointer], :int

    # attach_function :sam_hdr_tid2name, [:pointer, :int], :string

    # tbx

    class TbxConf < FFI::Struct
      layout :preset, :int32,
             :sc, :int32,
             :bc, :int32,
             :ec, :int32,
             :meta_char, :int32,
             :line_skip, :int32
    end

    class Tbx < FFI::Struct
      layout :conf, TbxConf,
             :idx, HtsIdx.ptr,
             :dict, :pointer
    end

    attach_function :tbx_name2id, [Tbx.by_ref, :string], :int
    attach_function :hts_get_bgzfp, [HtsFile.by_ref], BGZF.by_ref
    attach_function :tbx_readrec, [BGZF.by_ref, :pointer, :pointer, :pointer, :pointer], :int
    attach_function :tbx_index, [BGZF.by_ref, :int, TbxConf.by_ref], :int
    attach_function :tbx_index_build, [:string, :int, TbxConf.by_ref], :int
    attach_function :tbx_index_build2, [:string, :string, :int, TbxConf.by_ref], :int
    attach_function :tbx_index_build3, [:string, :string, :int, :int, TbxConf.by_ref], :int
    attach_function :tbx_index_load, [:string], Tbx.by_ref
    attach_function :tbx_index_load2, %i[string string], Tbx.by_ref
    # attach_function :tbx_index_load3, %i[string string int], Tbx.by_ref
    attach_function :tbx_seqnames, [Tbx.by_ref, :int], :string
    attach_function :tbx_destroy, [Tbx.by_ref], :void

    # sam

    class SamHdr < FFI::Struct
      layout :n_targets, :int32,
             :ignore_sam_err, :int32,
             :l_text, :size_t,
             :target_len, :pointer,
             :cigar_tab, :pointer,
             :target_name, :pointer,
             :text, :string,
             :sdict, :pointer,
             :hrecs, :pointer,
             :ref_count, :uint32
    end
    BamHdr = SamHdr

    class Bam1Core < FFI::Struct
      layout :pos, :pointer, # hts_pos_t
             :tid, :int32,
             :bin, :uint16,
             :qual, :uint8,
             :l_extranul, :uint8,
             :flag, :uint16,
             :l_qname, :uint16,
             :n_cigar, :uint32,
             :l_qseq, :int32,
             :mtid, :int32,
             :mpos, :pointer, # hts_pos_t
             :isize, :pointer # hts_pos_t
    end

    class Bam1 < FFI::Struct
    end

    class BamPlp < FFI::Struct
    end

    class BamMplp < FFI::Struct
    end

    attach_function :sam_hdr_init, [], SamHdr.by_ref
    attach_function :bam_hdr_read, [BGZF.by_ref], SamHdr.by_ref
    attach_function :bam_hdr_write, [BGZF.by_ref, SamHdr.by_ref], :int
    attach_function :sam_hdr_destroy, [SamHdr.by_ref], :void
    attach_function :sam_hdr_dup, [SamHdr.by_ref], SamHdr.by_ref
    attach_function :sam_hdr_parse, %i[size_t string], SamHdr.by_ref
    attach_function :sam_hdr_read, [HtsFile.by_ref], SamHdr.by_ref
    attach_function :sam_hdr_write, [HtsFile.by_ref, SamHdr.by_ref], :int
    attach_function :sam_hdr_length, [SamHdr.by_ref], :size_t
    attach_function :sam_hdr_str, [SamHdr.by_ref], :string
    attach_function :sam_hdr_nref, [SamHdr.by_ref], :int
    attach_function :sam_hdr_add_lines, [SamHdr.by_ref, :string, :size_t], :int
    attach_function :sam_hdr_find_line_id, [SamHdr.by_ref, :string, :string, :string, Kstring.by_ref], :int
    attach_function :sam_hdr_find_line_pos, [SamHdr.by_ref, :string, :int, Kstring.by_ref], :int
    attach_function :sam_hdr_remove_line_id, [SamHdr.by_ref, :string, :string, :string], :int
    attach_function :sam_hdr_remove_line_pos, [SamHdr.by_ref, :string, :int], :int
    attach_function :sam_hdr_remove_except, [SamHdr.by_ref, :string, :string, :string], :int
    attach_function :sam_hdr_remove_lines, [SamHdr.by_ref, :string, :string, :pointer], :int
    attach_function :sam_hdr_count_lines, [SamHdr.by_ref, :string], :int
    attach_function :sam_hdr_line_index, [SamHdr.by_ref, :string, :string], :int
    attach_function :sam_hdr_line_name, [SamHdr.by_ref, :string, :int], :string
    attach_function :sam_hdr_find_tag_id, [SamHdr.by_ref, :string, :string, :string, :string, Kstring.by_ref], :int
    attach_function :sam_hdr_find_tag_pos, [SamHdr.by_ref, :string, :int, :string, Kstring.by_ref], :int
    attach_function :sam_hdr_remove_tag_id, [SamHdr.by_ref, :string, :string, :string, :string], :int
    attach_function :sam_hdr_name2tid, [SamHdr.by_ref, :string], :int
    attach_function :sam_hdr_tid2name, [SamHdr.by_ref, :int], :string
    attach_function :sam_hdr_tid2len, [SamHdr.by_ref, :int], :int64
    attach_function :sam_hdr_pg_id, [SamHdr.by_ref, :string], :string
    attach_function :stringify_argv, %i[int pointer], :string
    attach_function :sam_hdr_incr_ref, [SamHdr.by_ref], :void
    attach_function :bam_init1, [], Bam1.by_ref
    attach_function :bam_destroy1, [Bam1.by_ref], :void
    attach_function :bam_read1, [BGZF.by_ref, Bam1.by_ref], :int
    attach_function :bam_write1, [BGZF.by_ref, Bam1.by_ref], :int
    attach_function :bam_copy1, [Bam1.by_ref, Bam1.by_ref], Bam1.by_ref
    attach_function :bam_dup1, [Bam1.by_ref], Bam1.by_ref
    attach_function :bam_cigar2qlen, %i[int pointer], :int64
    attach_function :bam_cigar2rlen, %i[int pointer], :int64
    attach_function :bam_endpos, [Bam1.by_ref], :int64
    attach_function :bam_str2flag, [:string], :int
    attach_function :bam_flag2str, [:int], :string
    attach_function :bam_set_qname, [Bam1.by_ref, :string], :int
    attach_function :sam_idx_init, [HtsFile.by_ref, SamHdr.by_ref, :int, :string], :int
    attach_function :sam_idx_save, [HtsFile.by_ref], :int
    attach_function :sam_index_load, [HtsFile.by_ref, :string], HtsIdx.by_ref
    attach_function :sam_index_load2, [HtsFile.by_ref, :string, :string], HtsIdx.by_ref
    attach_function :sam_index_load3, [HtsFile.by_ref, :string, :string, :int], HtsIdx.by_ref
    attach_function :sam_index_build, %i[string int], :int
    attach_function :sam_index_build2, %i[string string int], :int
    attach_function :sam_index_build3, %i[string string int int], :int
    attach_function :sam_itr_queryi, [HtsIdx.by_ref, :int, :int64, :int64], HtsItr.by_ref
    attach_function :sam_itr_querys, [HtsIdx.by_ref, SamHdr.by_ref, :string], HtsItr.by_ref
    attach_function :sam_itr_regions, [HtsIdx.by_ref, SamHdr.by_ref, :pointer, :uint], HtsItr.by_ref
    attach_function :sam_itr_regarray, [HtsIdx.by_ref, SamHdr.by_ref, :pointer, :uint], HtsItr.by_ref
    attach_function :sam_parse_region, [SamHdr.by_ref, :string, :pointer, :pointer, :pointer, :int], :string
    attach_function :sam_open_mode, %i[string string string], :int
    attach_function :sam_open_mode_opts, %i[string string string], :string
    attach_function :sam_hdr_change_HD, [SamHdr.by_ref, :string, :string], :int
    attach_function :sam_parse1, [Kstring.by_ref, SamHdr.by_ref, Bam1.by_ref], :int
    attach_function :sam_format1, [SamHdr.by_ref, Bam1.by_ref, Kstring.by_ref], :int
    attach_function :sam_read1, [HtsFile.by_ref, SamHdr.by_ref, Bam1.by_ref], :int
    attach_function :sam_write1, [HtsFile.by_ref, SamHdr.by_ref, Bam1.by_ref], :int
    attach_function :bam_aux_get, [Bam1.by_ref, :string], :pointer
    attach_function :bam_aux2i, [:pointer], :int64
    attach_function :bam_aux2f, [:pointer], :double
    attach_function :bam_aux2A, [:pointer], :string
    attach_function :bam_aux2Z, [:pointer], :string
    attach_function :bam_auxB_len, [:pointer], :uint
    attach_function :bam_auxB2i, %i[pointer uint], :int64
    attach_function :bam_auxB2f, %i[pointer uint], :double
    attach_function :bam_aux_append, [Bam1.by_ref, :string, :string, :int, :pointer], :int
    attach_function :bam_aux_del, [Bam1.by_ref, :pointer], :int
    attach_function :bam_aux_update_str, [Bam1.by_ref, :string, :int, :string], :int
    attach_function :bam_aux_update_int, [Bam1.by_ref, :string, :int64], :int
    attach_function :bam_aux_update_float, [Bam1.by_ref, :string, :float], :int
    attach_function :bam_aux_update_array, [Bam1.by_ref, :string, :uint8, :uint, :pointer], :int
    # attach_function :bam_plp_init, [func::bam_plp_auto_f, :pointer ], BamPlp
    attach_function :bam_plp_destroy, [BamPlp], :void
    # attach_function :bam_plp_push, [iter::, Bam1.by_ref ], :int
    attach_function :bam_plp_next, [BamPlp, :pointer, :pointer, :pointer], :pointer
    attach_function :bam_plp_auto, [BamPlp, :pointer, :pointer, :pointer], :pointer
    attach_function :bam_plp64_next, [BamPlp, :pointer, :pointer, :pointer], :pointer
    attach_function :bam_plp64_auto, [BamPlp, :pointer, :pointer, :pointer], :pointer
    attach_function :bam_plp_set_maxcnt, [BamPlp, :int], :void
    attach_function :bam_plp_reset, [BamPlp], :void
    attach_function :bam_plp_insertion, [:pointer, Kstring.by_ref, :pointer], :int
    # attach_function :bam_mplp_init, [:int, func::bam_plp_auto_f, :pointer], BamMplp.by_ref
    attach_function :bam_mplp_init_overlaps, [BamMplp], :int
    attach_function :bam_mplp_destroy, [BamMplp], :void
    attach_function :bam_mplp_set_maxcnt, [BamMplp, :int], :void
    attach_function :bam_mplp_auto, [BamMplp, :pointer, :pointer, :pointer, :pointer], :int
    attach_function :bam_mplp64_auto, [BamMplp, :pointer, :pointer, :pointer, :pointer], :int
    attach_function :bam_mplp_reset, [BamMplp], :void
    attach_function :sam_cap_mapq, [Bam1.by_ref, :string, :int64, :int], :int
    attach_function :sam_prob_realn, [Bam1.by_ref, :string, :int64, :int], :int

    # kfunc

    attach_function :kf_lgamma, [:double], :double
    attach_function :kf_erfc, [:double], :double
    attach_function :kf_gammap, %i[double double], :double
    attach_function :kf_gammaq, %i[double double], :double
    attach_function :kf_betai, %i[double double double], :double
    attach_function :kt_fisher_exact, %i[int int int int pointer pointer pointer], :double

    # faidx

    FaiFormatOptions = enum(:FAI_NONE, :FAI_FASTA, :FAI_FASTQ)

    class Faidx < FFI::Struct
      layout :bgzf, BGZF.by_ref,
             :n, :int,
             :m, :int,
             :name, :pointer,
             :hash, :pointer,
             :format, FaiFormatOptions
    end

    attach_function :fai_build3, %i[string string string], :int
    attach_function :fai_build, [:string], :int
    attach_function :fai_destroy, [Faidx.by_ref], :void
    attach_function :fai_load3, %i[string string string int], Faidx.by_ref
    attach_function :fai_load, [:string], Faidx.by_ref
    # attach_function :fai_load3_format, [:string, :string, :string, :int, FaiFormatOptions], Faidx.by_ref
    # attach_function :fai_load_format, [:string, FaiFormatOptions], Faidx.by_ref
    attach_function :fai_fetch, [Faidx.by_ref, :string, :pointer], :string
    # attach_function :fai_fetch64, [Faidx.by_ref, :string, :int64], :string
    # attach_function :fai_fetchqual, [Faidx.by_ref, :string, :pointer], :string
    # attach_function :fai_fetchqual64, [Faidx.by_ref, :string, :int64], :string
    attach_function :faidx_fetch_nseq, [Faidx.by_ref], :int
    attach_function :faidx_fetch_seq, [Faidx.by_ref, :string, :int, :int, :pointer], :string
    # attach_function :faidx_fetch_seq64, [Faidx.by_ref, :string, :int64, :int64, :pointer], :string
    # attach_function :faidx_fetch_qual, [Faidx.by_ref, :string, :int, :int, :pointer], :string
    # attach_function :faidx_fetch_qual64, [Faidx.by_ref, :string, :int64, :int64, :pointer], :string
    attach_function :faidx_has_seq, [Faidx.by_ref, :string], :int
    attach_function :faidx_nseq, [Faidx.by_ref], :int
    attach_function :faidx_iseq, [Faidx.by_ref, :int], :string
    attach_function :faidx_seq_len, [Faidx.by_ref, :string], :int
    # attach_function :fai_parse_region, [Faidx.by_ref, :string, :pointer, :pointer, :pointer, :int], :string
    # attach_function :fai_set_cache_size, [Faidx.by_ref, :int], :void

    # vcf

    class Variant < FFI::Struct
      layout :type, :int,
             :n, :int
    end

    class BcfHrec < FFI::Struct
      layout :type, :int,
             :key, :string,
             :value, :string,
             :nkeys, :int,
             :keys, :pointer,
             :vals, :pointer
    end

    class BcfFmt < FFI::Struct
      layout :id, :int,
             :n, :int,
             :size, :int,
             :type, :int,
             :p, :pointer,
             :p_len, :uint32,
             :piyo, :uint32 # FIXME
    end

    class BcfInfo < FFI::Struct
      layout :key, :int,
             :type, :int,
             :v1, Class.new(FFI::Union) {
                    layout :i, :int64,
                           :f, :float
                  },
             :vptr, :pointer,
             :vptr_len, :uint32,
             :piyo, :uint32, # FIXME
             :len, :int
    end

    class BcfIdinfo < FFI::Struct
      layout :info, [:uint8, 3],
             :hrec, [BcfHrec.by_ref, 3],
             :id, :int
    end

    class BcfIdpair < FFI::Struct
      layout :key, :string,
             :val, BcfIdinfo.by_ref
    end

    class BcfHdr < FFI::Struct
      layout :n, [:int, 3],
             :id, [BcfIdpair.by_ref, 3],
             :dict, [:pointer, 3],
             :samples, :pointer,
             :hrec, :pointer,
             :nhrec, :int,
             :dirty, :int,
             :ntransl, :int,
             :transl, :pointer,
             :nsamples_ori, :int,
             :keep_samples, :pointer,
             :mem, Kstring,
             :m, [:int, 3]
    end

    class BcfDec < FFI::Struct
      layout :m_fmt, :int,
             :m_info, :int,
             :m_id, :int,
             :m_als, :int,
             :m_allele, :int,
             :m_flt, :int,
             :flt, :pointer,
             :id, :string,
             :als, :string,
             :allele, :pointer,
             :info, BcfInfo.by_ref,
             :fmt, BcfFmt.by_ref,
             :var, Variant.by_ref,
             :n_var, :int,
             :var_type, :int,
             :shared_dirty, :int,
             :indiv_dirty, :int
    end

    class Bcf1 < FFI::Struct
      layout :pos, :int64,
             :rlen, :int64,
             :rid, :int,
             :qual, :float,
             :piyo, :int, # FIXME
             :fuga, :int, # FIXME
             :shared, Kstring,
             :indiv, Kstring,
             :d, BcfDec,
             :max_unpack, :int,
             :unpacked, :int,
             :unpack_size, [:int, 3],
             :errcode, :int
    end
  end
end
