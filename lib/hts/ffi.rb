# frozen_string_literal: true

# This should be removed if you get the better way...
module FFI
  class Struct
    def self.union_layout(*args)
      Class.new(FFI::Union) { layout(*args) }
    end

    def self.struct_layout(*args)
      Class.new(FFI::Struct) { layout(*args) }
    end
  end
end

module HTS
  module FFI
    extend ::FFI::Library

    begin
      ffi_lib HTS.ffi_lib
    rescue LoadError => e
      raise LoadError, 'Could not find HTSlib.so'
    end

    def self.attach_function(*)
      super
    rescue ::FFI::NotFoundError => e
      warn e.message
    end

    # kstring

    class Kstring < ::FFI::Struct
      layout \
        :l,              :size_t,
        :m,              :size_t,
        :s,              :string
    end

    # hfile

    typedef :pointer, :HFILE

    attach_function   :hdopen,                 %i[int string],                    :HFILE
    attach_function   :hisremote,              [:string],                         :int
    # attach_function :haddextension,          [Kstring, :string, :int, :string], :string
    attach_function   :hclose,                 [:HFILE],                          :int
    attach_function   :hclose_abruptly,        [:HFILE],                          :void
    attach_function   :hseek,                  %i[HFILE off_t int],               :off_t
    attach_function   :hgetdelim,              %i[string size_t int HFILE],       :ssize_t
    attach_function   :hgets,                  %i[string int HFILE],              :string
    attach_function   :hpeek,                  %i[HFILE pointer size_t],          :ssize_t
    attach_function   :hflush,                 [:HFILE],                          :int
    attach_function   :hfile_mem_get_buffer,   %i[HFILE pointer],                 :string
    attach_function   :hfile_mem_steal_buffer, %i[HFILE pointer],                 :string

    # BGZF

    class BGZF < ::FFI::Struct
      layout \
        :piyo,                   :uint, # FIXME
        :cache_size,             :int,
        :block_length,           :int,
        :block_clength,          :int,
        :block_offset,           :int,
        :block_address,          :int64,
        :uncompressed_address,   :int64,
        :uncompressed_block,     :pointer,
        :compressed_block,       :pointer,
        :cache,                  :pointer,
        :fp,                     :HFILE,
        :mt,                     :pointer,
        :idx,                    :pointer,
        :idx_build_otf,          :int,
        :gz_stream,              :pointer,
        :seeked,                 :int64
    end

    attach_function   :bgzf_dopen,             %i[int string],                         BGZF.by_ref
    attach_function   :bgzf_open,              %i[string string],                      BGZF.by_ref
    attach_function   :bgzf_hopen,             %i[HFILE string],                       BGZF.by_ref
    attach_function   :bgzf_close,             [:HFILE],                               :int
    attach_function   :bgzf_read,              %i[HFILE pointer size_t],               :size_t
    attach_function   :bgzf_write,             [BGZF, :pointer, :size_t],              :ssize_t
    # attach_function :bgzf_peek,              [BGZF],                                 :int
    attach_function   :bgzf_raw_read,          [BGZF, :pointer, :size_t],              :ssize_t
    attach_function   :bgzf_raw_write,         [BGZF, :pointer, :size_t],              :ssize_t
    attach_function   :bgzf_flush,             [BGZF],                                 :int
    attach_function   :bgzf_seek,              [BGZF, :int64, :int],                   :int64
    attach_function   :bgzf_check_EOF,         [BGZF],                                 :int
    attach_function   :bgzf_compression,       [BGZF],                                 :int
    attach_function   :bgzf_is_bgzf,           [:string],                              :int
    attach_function   :bgzf_set_cache_size,    [BGZF, :int],                           :void
    attach_function   :bgzf_flush_try,         [BGZF, :ssize_t],                       :int
    attach_function   :bgzf_getc,              [BGZF],                                 :int
    attach_function   :bgzf_getline,           [BGZF, :int, Kstring],                  :int
    attach_function   :bgzf_read_block,        [BGZF],                                 :int
    attach_function   :bgzf_mt,                [BGZF, :int, :int],                     :int
    attach_function   :bgzf_compress,          %i[pointer pointer pointer size_t int], :int
    attach_function   :bgzf_useek,             [BGZF, :off_t, :int],                   :int
    attach_function   :bgzf_utell,             [BGZF],                                 :off_t
    attach_function   :bgzf_index_build_init,  [BGZF],                                 :int
    attach_function   :bgzf_index_load,        [BGZF, :string, :string],               :int
    attach_function   :bgzf_index_load_hfile,  [BGZF, :HFILE, :string],                :int
    attach_function   :bgzf_index_dump,        [BGZF, :string, :string],               :int
    attach_function   :bgzf_index_dump_hfile,  [BGZF, :HFILE, :string],                :int

    # hts

    # Should this start with small character? For example, htsFromatCategory
    HtsFormatCategory = enum(
      :unknown_category, :sequence_data, :variant_data, :index_file, :region_list, :category_maximum
    )

    HtsExactFormat = enum(
      :unknown_format, :binary_format, :text_format, :sam, :bam, :bai, :cram, :crai, :vcf, :bcf,
      :csi, :gzi, :tbi, :bed, :format_maximum
    )

    HtsCompression = enum(
      :no_compression, :gzip, :bgzf, :custom, :compression_maximum
    )

    HtsFmtOption = enum(
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

    # Should this be located at HTSlib Module? not HTSlib::FFI?
    class HtsFormat < ::FFI::Struct
      layout \
        :category,          HtsFormatCategory,
        :format,            HtsExactFormat,
        :version,
        struct_layout(
          :major,           :short,
          :minor,           :short
        ),
        :compression,       HtsCompression,
        :compression_lebel, :short,
        :specific,          :pointer
    end

    class HtsIdx < ::FFI::Struct
      layout \
        :fmt,            :int,
        :min_shift,      :int,
        :n_lvls,         :int,
        :n_bins,         :int,
        :l_meta,         :uint32,
        :n,              :int32,
        :m,              :int32,
        :n_no_coor,      :uint64,
        :bidx,           :pointer,
        :lidx,           :pointer,
        :meta,           :pointer,
        :tbi_n,          :int,
        :last_tbi_tid,   :int,
        :z,
        union_layout(
          :last_bin,     :uint32,
          :save_bin,     :uint32,
          :last_coor,    :pointer,
          :last_tid,     :int,
          :save_tid,     :int,
          :finished,     :int,
          :last_off,     :uint64,
          :save_off,     :uint64,
          :off_beg,      :uint64,
          :off_end,      :uint64,
          :n_mapped,     :uint64,
          :n_unmapped,   :uint64
        )
    end

    class SamHdr < ::FFI::Struct # HtsFile
      layout \
        :n_targets,      :int32,
        :ignore_sam_err, :int32,
        :l_text,         :size_t,
        :target_len,     :pointer,
        :cigar_tab,      :pointer,
        :target_name,    :pointer,
        :text,           :string,
        :sdict,          :pointer,
        :hrecs,          :pointer,
        :ref_count,      :uint32
    end
    BamHdr = SamHdr

    class HtsFile < ::FFI::Struct
      layout \
        :bitfields,      :uint32, # FIXME
        :lineno,         :int64,
        :line,           Kstring,
        :fn,             :string,
        :fn_aux,         :string,
        :fp,
        union_layout(
          :bgzf,         BGZF.ptr,
          :cram,         :pointer,
          :hfile,        :pointer # HFILE
        ),
        :state,          :pointer,
        :format,         HtsFormat,
        :idx,            HtsIdx.ptr,
        :fnidx,          :string,
        :bam_header,     SamHdr.ptr
    end
    SamFile = HtsFile

    class HtsThreadPool < ::FFI::Struct
      layout \
        :pool,           :pointer,
        :qsize,          :int
    end

    class HtsOpt < ::FFI::Struct
      layout \
        :arg,            :string,
        :opt,            HtsFmtOption,
        :val,
        union_layout(
          :i,            :int,
          :s,            :string
        ),
        :next,           HtsOpt.ptr
    end

    class HtsItr < ::FFI::Struct
      layout \
        :foo,            :uint32, # FIXME
        :tid,            :int,
        :n_off,          :int,
        :i,              :int,
        :n_reg,          :int,
        :beg,            :int64,
        :end,            :int64,
        :reg_list,       :pointer,
        :curr_tid,       :int,
        :curr_reg,       :int,
        :curr_intv,      :int,
        :curr_beg,       :int64,
        :curr_end,       :int64,
        :curr_off,       :uint64,
        :nocoor_off,     :uint64,
        :off,            :pointer,
        :readrec,        :pointer,
        :seek,           :pointer,
        :tell,           :pointer,
        :bins,
        union_layout(
          :n,            :int,
          :m,            :int,
          :a,            :pointer
        )
    end

    # sam

    typedef :int64, :hts_pos_t

    class Bam1Core < ::FFI::Struct
      layout \
        :pos,            :hts_pos_t,
        :tid,            :int32,
        :bin,            :uint16,
        :qual,           :uint8,
        :l_extranul,     :uint8,
        :flag,           :uint16,
        :l_qname,        :uint16,
        :n_cigar,        :uint32,
        :l_qseq,         :int32,
        :mtid,           :int32,
        :mpos,           :hts_pos_t,
        :isize,          :hts_pos_t
    end

    class Bam1 < ::FFI::Struct
      layout \
        :core,           Bam1Core,
        :id,             :uint64,
        :data,           :pointer, # uint8_t
        :l_data,         :int,
        :m_data,         :uint32,
        :mempolicy,      :uint32
    end

    class BamPlp < ::FFI::Struct
    end

    class BamMplp < ::FFI::Struct
    end

    BAM_CMATCH     = 0
    BAM_CINS       = 1
    BAM_CDEL       = 2
    BAM_CREF_SKIP  = 3
    BAM_CSOFT_CLIP = 4
    BAM_CHARD_CLIP = 5
    BAM_CPAD       = 6
    BAM_CEQUAL     = 7
    BAM_CDIFF      = 8
    BAM_CBACK      = 9

    BAM_CIGAR_STR   = "MIDNSHP=XB"
    _BAM_CIGAR_STR_PADDED = "MIDNSHP=XB??????"
    BAM_CIGAR_SHIFT = 4
    BAM_CIGAR_MASK  = 0xf
    BAM_CIGAR_TYPE  = 0x3C1A7

    class << self
      def bam_cigar_op(c)
        c & BAM_CIGAR_MASK
      end

      def bam_cigar_oplen(c)
        c >> BAM_CIGAR_SHIFT
      end

      def bam_cigar_opchar(c)
        _BAM_CIGAR_STR_PADDED[bam_cigar_op(c)]
      end

      def bam_cigar_gen(l, o)
        l << BAM_CIGAR_SHIFT | o
      end

      def bam_cigar_type(o)
        BAM_CIGAR_TYPE >> (o<<1) & 3
      end
    end

    BAM_FPAIRED        =    1
    BAM_FPROPER_PAIR   =    2
    BAM_FUNMAP         =    4
    BAM_FMUNMAP        =    8
    BAM_FREVERSE       =   16
    BAM_FMREVERSE      =   32
    BAM_FREAD1         =   64
    BAM_FREAD2         =  128
    BAM_FSECONDARY     =  256
    BAM_FQCFAIL        =  512
    BAM_FDUP           = 1024
    BAM_FSUPPLEMENTARY = 2048

    # function-like macros
    class << self
      def bam_is_rev(b)
        b[:core][:flag] & BAM_FREVERSE != 0
      end

      def bam_is_mrev(b)
        b[:core][:flag] & BAM_FMREVERSE != 0
      end

      def bam_get_qname(b)
        b[:data]
      end

      def bam_get_cigar(b)
        b[:data] + b[:core][:l_qname]
      end
  
      def bam_get_seq(b)
        b[:data] + (b[:core][:n_cigar] << 2) + b[:core][:l_qname]
      end

      def bam_get_qual(b)
        b[:data] + (b[:core][:n_cigar] << 2) + b[:core][:l_qname] + ((b[:core][:l_qseq] + 1) >> 1)
      end

      def bam_get_aux(b)
        b[:data] + (b[:core][:n_cigar] << 2) + b[:core][:l_qname] + ((b[:core][:l_qseq] + 1) >> 1) + b[:core][:l_qseq]
      end

      def bam_get_l_aux(b)
        b[:l_data] - (b[:core][:n_cigar] << 2) - b[:core][:l_qname] - b[:core][:l_qseq] - ((b[:core][:l_qseq] + 1) >> 1)
      end

      # def bam_seqi(s, i)

      # def bam_set_seqi(s, i, b)
    end

    attach_function   :sam_hdr_init,            [],                                                    SamHdr.by_ref
    attach_function   :bam_hdr_read,            [BGZF],                                                SamHdr.by_ref
    attach_function   :bam_hdr_write,           [BGZF, SamHdr],                                        :int
    attach_function   :sam_hdr_destroy,         [SamHdr],                                              :void
    attach_function   :sam_hdr_dup,             [SamHdr],                                              SamHdr.by_ref
    attach_function   :sam_hdr_parse,           %i[size_t string],                                     SamHdr.by_ref
    attach_function   :sam_hdr_read,            [HtsFile],                                             SamHdr.by_ref
    attach_function   :sam_hdr_write,           [HtsFile, SamHdr],                                     :int
    attach_function   :sam_hdr_length,          [SamHdr],                                              :size_t
    attach_function   :sam_hdr_str,             [SamHdr],                                              :string
    attach_function   :sam_hdr_nref,            [SamHdr],                                              :int
    attach_function   :sam_hdr_add_lines,       [SamHdr, :string, :size_t],                            :int
    attach_function   :sam_hdr_find_line_id,    [SamHdr, :string, :string, :string, Kstring],          :int
    attach_function   :sam_hdr_find_line_pos,   [SamHdr, :string, :int, Kstring],                      :int
    attach_function   :sam_hdr_remove_line_id,  [SamHdr, :string, :string, :string],                   :int
    attach_function   :sam_hdr_remove_line_pos, [SamHdr, :string, :int],                               :int
    attach_function   :sam_hdr_remove_except,   [SamHdr, :string, :string, :string],                   :int
    attach_function   :sam_hdr_remove_lines,    [SamHdr, :string, :string, :pointer],                  :int
    attach_function   :sam_hdr_count_lines,     [SamHdr, :string],                                     :int
    attach_function   :sam_hdr_line_index,      [SamHdr, :string, :string],                            :int
    attach_function   :sam_hdr_line_name,       [SamHdr, :string, :int],                               :string
    attach_function   :sam_hdr_find_tag_id,     [SamHdr, :string, :string, :string, :string, Kstring], :int
    attach_function   :sam_hdr_find_tag_pos,    [SamHdr, :string, :int, :string, Kstring],             :int
    attach_function   :sam_hdr_remove_tag_id,   [SamHdr, :string, :string, :string, :string],          :int
    attach_function   :sam_hdr_name2tid,        [SamHdr, :string],                                     :int
    attach_function   :sam_hdr_tid2name,        [SamHdr, :int],                                        :string
    attach_function   :sam_hdr_tid2len,         [SamHdr, :int],                                        :int64
    attach_function   :sam_hdr_pg_id,           [SamHdr, :string],                                     :string
    attach_function   :stringify_argv,          %i[int pointer],                                       :string
    attach_function   :sam_hdr_incr_ref,        [SamHdr],                                              :void
    attach_function   :bam_init1,               [],                                                    Bam1.by_ref
    attach_function   :bam_destroy1,            [Bam1],                                                :void
    attach_function   :bam_read1,               [BGZF, Bam1],                                          :int
    attach_function   :bam_write1,              [BGZF, Bam1],                                          :int
    attach_function   :bam_copy1,               [Bam1, Bam1],                                          Bam1.by_ref
    attach_function   :bam_dup1,                [Bam1],                                                Bam1.by_ref
    attach_function   :bam_cigar2qlen,          %i[int pointer],                                       :int64
    attach_function   :bam_cigar2rlen,          %i[int pointer],                                       :int64
    attach_function   :bam_endpos,              [Bam1],                                                :int64
    attach_function   :bam_str2flag,            [:string],                                             :int
    attach_function   :bam_flag2str,            [:int],                                                :string
    attach_function   :bam_set_qname,           [Bam1, :string],                                       :int
    attach_function   :sam_idx_init,            [HtsFile, SamHdr, :int, :string],                      :int
    attach_function   :sam_idx_save,            [HtsFile],                                             :int
    attach_function   :sam_index_load,          [HtsFile, :string],                                    HtsIdx.by_ref
    attach_function   :sam_index_load2,         [HtsFile, :string, :string],                           HtsIdx.by_ref
    attach_function   :sam_index_load3,         [HtsFile, :string, :string, :int],                     HtsIdx.by_ref
    attach_function   :sam_index_build,         %i[string int],                                        :int
    attach_function   :sam_index_build2,        %i[string string int],                                 :int
    attach_function   :sam_index_build3,        %i[string string int int],                             :int
    attach_function   :sam_itr_queryi,          [HtsIdx, :int, :int64, :int64],                        HtsItr.by_ref
    attach_function   :sam_itr_querys,          [HtsIdx, SamHdr, :string],                             HtsItr.by_ref
    attach_function   :sam_itr_regions,         [HtsIdx, SamHdr, :pointer, :uint],                     HtsItr.by_ref
    attach_function   :sam_itr_regarray,        [HtsIdx, SamHdr, :pointer, :uint],                     HtsItr.by_ref
    attach_function   :sam_parse_region,        [SamHdr, :string, :pointer, :pointer, :pointer, :int], :string
    attach_function   :sam_open_mode,           %i[string string string],                              :int
    attach_function   :sam_open_mode_opts,      %i[string string string],                              :string
    attach_function   :sam_hdr_change_HD,       [SamHdr, :string, :string],                            :int
    attach_function   :sam_parse1,              [Kstring, SamHdr, Bam1],                               :int
    attach_function   :sam_format1,             [SamHdr, Bam1, Kstring],                               :int
    attach_function   :sam_read1,               [HtsFile, SamHdr, Bam1],                               :int
    attach_function   :sam_write1,              [HtsFile, SamHdr, Bam1],                               :int
    attach_function   :bam_aux_get,             [Bam1, :string],                                       :pointer
    attach_function   :bam_aux2i,               [:pointer],                                            :int64
    attach_function   :bam_aux2f,               [:pointer],                                            :double
    attach_function   :bam_aux2A,               [:pointer],                                            :string
    attach_function   :bam_aux2Z,               [:pointer],                                            :string
    attach_function   :bam_auxB_len,            [:pointer],                                            :uint
    attach_function   :bam_auxB2i,              %i[pointer uint],                                      :int64
    attach_function   :bam_auxB2f,              %i[pointer uint],                                      :double
    attach_function   :bam_aux_append,          [Bam1, :string, :string, :int, :pointer],              :int
    attach_function   :bam_aux_del,             [Bam1, :pointer],                                      :int
    attach_function   :bam_aux_update_str,      [Bam1, :string, :int, :string],                        :int
    attach_function   :bam_aux_update_int,      [Bam1, :string, :int64],                               :int
    attach_function   :bam_aux_update_float,    [Bam1, :string, :float],                               :int
    attach_function   :bam_aux_update_array,    [Bam1, :string, :uint8, :uint, :pointer],              :int
    # attach_function :bam_plp_init,            [func::bam_plp_auto_f, :pointer ],                     BamPlp
    attach_function   :bam_plp_destroy,         [BamPlp],                                              :void
    # attach_function :bam_plp_push,            [iter::, Bam1 ],                                       :int
    attach_function   :bam_plp_next,            [BamPlp, :pointer, :pointer, :pointer],                :pointer
    attach_function   :bam_plp_auto,            [BamPlp, :pointer, :pointer, :pointer],                :pointer
    attach_function   :bam_plp64_next,          [BamPlp, :pointer, :pointer, :pointer],                :pointer
    attach_function   :bam_plp64_auto,          [BamPlp, :pointer, :pointer, :pointer],                :pointer
    attach_function   :bam_plp_set_maxcnt,      [BamPlp, :int],                                        :void
    attach_function   :bam_plp_reset,           [BamPlp],                                              :void
    attach_function   :bam_plp_insertion,       [:pointer, Kstring, :pointer],                         :int
    # attach_function :bam_mplp_init,           [:int, func::bam_plp_auto_f, :pointer],                BamMplp.by_ref
    attach_function   :bam_mplp_init_overlaps,  [BamMplp],                                             :int
    attach_function   :bam_mplp_destroy,        [BamMplp],                                             :void
    attach_function   :bam_mplp_set_maxcnt,     [BamMplp, :int],                                       :void
    attach_function   :bam_mplp_auto,           [BamMplp, :pointer, :pointer, :pointer, :pointer],     :int
    attach_function   :bam_mplp64_auto,         [BamMplp, :pointer, :pointer, :pointer, :pointer],     :int
    attach_function   :bam_mplp_reset,          [BamMplp], :void
    attach_function   :sam_cap_mapq,            [Bam1, :string, :int64, :int],                         :int
    attach_function   :sam_prob_realn,          [Bam1, :string, :int64, :int],                         :int

    # kfunc

    attach_function   :kf_lgamma,               [:double],                                             :double
    attach_function   :kf_erfc,                 [:double],                                             :double
    attach_function   :kf_gammap,               %i[double double],                                     :double
    attach_function   :kf_gammaq,               %i[double double],                                     :double
    attach_function   :kf_betai,                %i[double double double],                              :double
    attach_function   :kt_fisher_exact,         %i[int int int int pointer pointer pointer],           :double

    # hts

    # attach_function :hts_free, [:pointer], :void
    # attach_function :hts_opt_add
    attach_function   :hts_opt_apply,             [HtsFile, HtsOpt],              :int
    attach_function   :hts_opt_free,              [HtsOpt],                       :void
    attach_function   :hts_parse_format,          [HtsFormat, :string],           :int
    attach_function   :hts_parse_opt_list,        [HtsFormat, :string],           :int
    attach_function   :hts_version,               %i[],                           :string
    attach_function   :hts_detect_format,         [:HFILE, HtsFormat], :int
    attach_function   :hts_format_description,    [HtsFormat],                    :string
    attach_function   :hts_open,                  %i[string string],              HtsFile.by_ref
    attach_function   :hts_open_format,           [:string, :string, HtsFormat],  HtsFile.by_ref
    attach_function   :hts_hopen,                 %i[HFILE string string], HtsFile.by_ref
    attach_function   :hts_close,                 [HtsFile],                      :int
    attach_function   :hts_get_format,            [HtsFile],                      HtsFormat.by_ref
    attach_function   :hts_format_file_extension, [HtsFormat],                    :string
    # attach_function :hts_set_opt
    attach_function   :hts_getline,               [HtsFile, :int, Kstring],       :int
    attach_function   :hts_readlines,             %i[string pointer],             :pointer
    attach_function   :hts_readlist,              %i[string int pointer],         :pointer

    attach_function   :hts_set_threads,           [HtsFile, :int],                :int
    attach_function   :hts_set_thread_pool,       [HtsFile, HtsThreadPool],       :int
    attach_function   :hts_set_cache_size,        [HtsFile, :int],                :void
    attach_function   :hts_set_fai_filename,      [HtsFile, :string],             :int
    attach_function   :hts_check_EOF,             [HtsFile],                      :int

    # typedef int64_t hts_pos_t;

    attach_function   :hts_idx_init,              %i[int int uint64 int int],                    :pointer
    attach_function   :hts_idx_destroy,           [HtsIdx],                                      :void
    attach_function   :hts_idx_push,              [HtsIdx, :int, :int64, :int64, :uint64, :int], :int
    attach_function   :hts_idx_finish,            [HtsIdx, :uint64],                             :int
    # attach_function :hts_idx_fmt,               [HtsIdx],                                      :int
    # attach_function :hts_idx_tbi_name,          [HtsIdx, :int, :string],                       :int
    attach_function   :hts_idx_save,              [HtsIdx, :string, :int],                       :int
    attach_function   :hts_idx_save_as,           [HtsIdx, :string, :string, :int],              :int
    attach_function   :hts_idx_load,              %i[string int],                                HtsIdx.by_ref
    attach_function   :hts_idx_load2,             %i[string string],                             HtsIdx.by_ref
    # attach_function :hts_idx_load3,             %i[string string int int],                     HtsIdx.by_ref
    attach_function   :hts_idx_get_meta,          [HtsIdx, :pointer],                           :uint8
    attach_function   :hts_idx_set_meta,          [HtsIdx, :uint32, :pointer, :int],            :int
    attach_function   :hts_idx_get_stat,          [HtsIdx, :int, :pointer, :pointer],           :int
    attach_function   :hts_idx_get_n_no_coor,     [HtsIdx], :uint64
    attach_function   :hts_parse_decimal,         %i[string pointer int],                       :long_long
    # attach_function :hts_parse_reg64,           %i[string pointer pointer],                   :string
    attach_function   :hts_parse_reg,             %i[string pointer pointer],                   :string
    # attach_function :hts_parse_region,          %i[string pointer pointer pointer pointer int]
    # attach_function :hts_itr_query
    attach_function   :hts_itr_destroy,           [HtsItr],                                     :void
    # attach_function :hts_itr_querys
    attach_function   :hts_itr_next,              [BGZF, HtsItr, :pointer, :pointer],           :int

    # attach_function :sam_hdr_tid2name,          [:pointer, :int],                             :string

    # tbx

    class TbxConf < ::FFI::Struct
      layout \
        :preset,         :int32,
        :sc,             :int32,
        :bc,             :int32,
        :ec,             :int32,
        :meta_char,      :int32,
        :line_skip,      :int32
    end

    class Tbx < ::FFI::Struct
      layout \
        :conf,           TbxConf.ptr,
        :idx,            HtsIdx.ptr,
        :dict,           :pointer
    end

    attach_function   :tbx_name2id,        [Tbx, :string],                                 :int
    attach_function   :hts_get_bgzfp,      [HtsFile],                                      BGZF.by_ref
    attach_function   :tbx_readrec,        [BGZF, :pointer, :pointer, :pointer, :pointer], :int
    attach_function   :tbx_index,          [BGZF, :int, TbxConf],                          :int
    attach_function   :tbx_index_build,    [:string, :int, TbxConf],                       :int
    attach_function   :tbx_index_build2,   [:string, :string, :int, TbxConf],              :int
    attach_function   :tbx_index_build3,   [:string, :string, :int, :int, TbxConf],        :int
    attach_function   :tbx_index_load,     [:string],                                      Tbx.by_ref
    attach_function   :tbx_index_load2,    %i[string string],                              Tbx.by_ref
    # attach_function :tbx_index_load3,    %i[string string int],                          Tbx.by_ref
    attach_function   :tbx_seqnames,       [Tbx, :int],                                    :string
    attach_function   :tbx_destroy,        [Tbx],                                          :void

    # faidx

    FaiFormatOptions = enum(:FAI_NONE, :FAI_FASTA, :FAI_FASTQ)

    class Faidx < ::FFI::Struct
      layout :bgzf,      BGZF,
             :n,         :int,
             :m,         :int,
             :name,      :pointer,
             :hash,      :pointer,
             :format,    FaiFormatOptions
    end

    attach_function   :fai_build3,         %i[string string string],                             :int
    attach_function   :fai_build,          [:string],                                            :int
    attach_function   :fai_destroy,        [Faidx],                                              :void
    attach_function   :fai_load3,          %i[string string string int],                         Faidx.by_ref
    attach_function   :fai_load,           [:string],                                            Faidx.by_ref
    # attach_function :fai_load3_format,   [:string, :string, :string, :int, FaiFormatOptions],  Faidx.by_ref
    # attach_function :fai_load_format,    [:string, FaiFormatOptions],                          Faidx.by_ref
    attach_function   :fai_fetch,          [Faidx, :string, :pointer],                           :string
    # attach_function :fai_fetch64,        [Faidx, :string, :int64],                             :string
    # attach_function :fai_fetchqual,      [Faidx, :string, :pointer],                           :string
    # attach_function :fai_fetchqual64,    [Faidx, :string, :int64],                             :string
    attach_function   :faidx_fetch_nseq,   [Faidx],                                              :int
    attach_function   :faidx_fetch_seq,    [Faidx, :string, :int, :int, :pointer],               :string
    # attach_function :faidx_fetch_seq64,  [Faidx, :string, :int64, :int64, :pointer],           :string
    # attach_function :faidx_fetch_qual,   [Faidx, :string, :int, :int, :pointer],               :string
    # attach_function :faidx_fetch_qual64, [Faidx, :string, :int64, :int64, :pointer],           :string
    attach_function   :faidx_has_seq,      [Faidx, :string],                                     :int
    attach_function   :faidx_nseq,         [Faidx],                                              :int
    attach_function   :faidx_iseq,         [Faidx, :int],                                        :string
    attach_function   :faidx_seq_len,      [Faidx, :string],                                     :int
    # attach_function :fai_parse_region,   [Faidx, :string, :pointer, :pointer, :pointer, :int], :string
    # attach_function :fai_set_cache_size, [Faidx, :int],                                        :void

    # vcf

    class Variant < ::FFI::Struct
      layout \
        :type,           :int,
        :n,              :int
    end

    class BcfHrec < ::FFI::Struct
      layout \
        :type,           :int,
        :key,            :string,
        :value,          :string,
        :nkeys,          :int,
        :keys,           :pointer,
        :vals,           :pointer
    end

    class BcfFmt < ::FFI::Struct
      layout \
        :id,             :int,
        :n,              :int,
        :size,           :int,
        :type,           :int,
        :p,              :pointer, # uint8_t
        :p_len,          :uint32,
        :piyo,           :uint32 # FIXME
    end

    class BcfInfo < ::FFI::Struct
      layout \
        :key,            :int,
        :type,           :int,
        :v1,
        union_layout(
          :i,            :int64,
          :f,            :float
        ),
        :vptr,           :pointer,
        :vptr_len,       :uint32,
        :piyo,           :uint32, # FIXME
        :len,            :int
    end

    class BcfIdinfo < ::FFI::Struct
      layout \
        :info,           [:uint8, 3],
        :hrec,           [BcfHrec.ptr, 3],
        :id,             :int
    end

    class BcfIdpair < ::FFI::Struct
      layout \
        :key,            :string,
        :val,            BcfIdinfo.ptr
    end

    class BcfHdr < ::FFI::Struct
      layout \
        :n,              [:int, 3],
        :id,             [BcfIdpair.ptr, 3],
        :dict,           [:pointer, 3],
        :samples,        :pointer,
        :hrec,           :pointer,
        :nhrec,          :int,
        :dirty,          :int,
        :ntransl,        :int,
        :transl,         :pointer,
        :nsamples_ori,   :int,
        :keep_samples,   :pointer,
        :mem,            Kstring,
        :m,              [:int, 3]
    end

    class BcfDec < ::FFI::Struct
      layout \
        :m_fmt,          :int,
        :m_info,         :int,
        :m_id,           :int,
        :m_als,          :int,
        :m_allele,       :int,
        :m_flt,          :int,
        :flt,            :pointer,
        :id,             :string,
        :als,            :string,
        :allele,         :pointer,
        :info,           BcfInfo.ptr,
        :fmt,            BcfFmt.ptr,
        :var,            Variant.ptr,
        :n_var,          :int,
        :var_type,       :int,
        :shared_dirty,   :int,
        :indiv_dirty,    :int
    end

    class Bcf1 < ::FFI::Struct
      layout \
        :pos,            :hts_pos_t,
        :rlen,           :hts_pos_t,
        :rid,            :int,
        :qual,           :float,
        :piyo,           :int, # FIXME
        :fuga,           :int, # FIXME
        :shared,         Kstring,
        :indiv,          Kstring,
        :d,              BcfDec,
        :max_unpack,     :int,
        :unpacked,       :int,
        :unpack_size,    [:int, 3],
        :errcode,        :int
    end
  end
end
