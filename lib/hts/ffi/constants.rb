# frozen_string_literal: true

module HTS
  module FFI
    typedef :pointer, :HFILE
    typedef :int64, :hts_pos_t
    typedef :pointer, :bam_plp_auto_f

    # kstring

    class KString < ::FFI::Struct
      layout \
        :l,              :size_t,
        :m,              :size_t,
        :s,              :string
    end

    class KSeq < ::FFI::Struct
      layout \
        :name,           KString,
        :comment,        KString,
        :seq,            KString,
        :qual,           KString,
        :last_char,      :int,
        :f,              :pointer # kstream_t
    end

    # BGZF
    class BGZF < ::FFI::BitStruct
      layout \
        :_flags,                 :uint, # bitfields
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

      bitfields :_flags,
                :errcode, 16,
                :reserved,       1,
                :is_write,       1,
                :no_eof_block,   1,
                :is_be,          1,
                :compress_level, 9,
                :last_block_eof, 1,
                :is_compressed,  1,
                :is_gzip,        1
    end

    # hts
    HtsLogLevel = enum(
      :off,            # All logging disabled.
      :error,          # Logging of errors only.
      :warning, 3,     # Logging of errors and warnings.
      :info,           # Logging of errors, warnings, and normal but significant events.
      :debug,          # Logging of all except the most detailed debug events.
      :trace           # All logging enabled.
    )

    HtsFormatCategory = enum(
      :unknown_category,
      :sequence_data,    # Sequence data -- SAM, BAM, CRAM, etc
      :variant_data,     # Variant calling data -- VCF, BCF, etc
      :index_file,       # Index file associated with some data file
      :region_list,      # Coordinate intervals or regions -- BED, etc
      :category_maximum, 32_767
    )

    HtsExactFormat = enum(
      :unknown_format,
      :binary_format, :text_format,
      :sam, :bam, :bai, :cram, :crai, :vcf, :bcf, :csi, :gzi, :tbi, :bed,
      :htsget, :json,
      :empty_format,
      :fasta_format, :fastq_format, :fai_format, :fqi_format,
      :hts_crypt4gh_format,
      :format_maximum, 32_767
    )

    HtsCompression = enum(
      :no_compression, :gzip, :bgzf, :custom,
      :compression_maximum, 32_767
    )

    HtsFmtOption = enum(
      :CRAM_OPT_DECODE_MD,
      :CRAM_OPT_PREFIX,
      :CRAM_OPT_VERBOSITY,   # obsolete, use hts_set_log_level() instead
      :CRAM_OPT_SEQS_PER_SLICE,
      :CRAM_OPT_SLICES_PER_CONTAINER,
      :CRAM_OPT_RANGE,
      :CRAM_OPT_VERSION,     # rename to :CRAM_version?
      :CRAM_OPT_EMBED_REF,
      :CRAM_OPT_IGNORE_MD5,
      :CRAM_OPT_REFERENCE,   # make general
      :CRAM_OPT_MULTI_SEQ_PER_SLICE,
      :CRAM_OPT_NO_REF,
      :CRAM_OPT_USE_BZIP2,
      :CRAM_OPT_SHARED_REF,
      :CRAM_OPT_NTHREADS,    # deprecated, use HTS_OPT_NTHREADS
      :CRAM_OPT_THREAD_POOL, # make general
      :CRAM_OPT_USE_LZMA,
      :CRAM_OPT_USE_RANS,
      :CRAM_OPT_REQUIRED_FIELDS,
      :CRAM_OPT_LOSSY_NAMES,
      :CRAM_OPT_BASES_PER_SLICE,
      :CRAM_OPT_STORE_MD,
      :CRAM_OPT_STORE_NM,
      :CRAM_OPT_RANGE_NOSEEK, # CRAM_OPT_RANGE minus the seek
      # General purpose
      :HTS_OPT_COMPRESSION_LEVEL, 100,
      :HTS_OPT_NTHREADS,
      :HTS_OPT_THREAD_POOL,
      :HTS_OPT_CACHE_SIZE,
      :HTS_OPT_BLOCK_SIZE
    )

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
        :compression_level, :short,
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

    # HtsFile
    class SamHdr < ::FFI::Struct
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

    class HtsFile < ::FFI::BitStruct
      layout \
        :_flags,         :uint32, # bitfields
        :lineno,         :int64,
        :line,           KString,
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

      bitfields :_flags,
                :is_bin,         1,
                :is_write,       1,
                :is_be,          1,
                :is_cram,        1,
                :is_bgzf,        1,
                :dummy,          27
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

    class HtsItr < ::FFI::BitStruct
      layout \
        :_flags,         :uint32, # bitfields
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

      bitfields :_flags,
                :read_rest, 1,
                :finished,  1,
                :is_cram,   1,
                :nocoor,    1,
                :multi,     1,
                :dummy,     27
    end

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
        :_mempolicy,     :uint32 # bitfields

      # bitfields :_mempolicy,
      #           :mempolicy,  2,
      #           :reserved,  30
    end

    class BamPlp < ::FFI::Struct
    end

    class BamMplp < ::FFI::Struct
    end

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

    class BcfFmt < ::FFI::BitStruct
      layout \
        :id,             :int,
        :n,              :int,
        :size,           :int,
        :type,           :int,
        :p,              :pointer, # uint8_t
        :p_len,          :uint32,
        :_p_off_free, :uint32 # bitfields

      bitfields :_p_off_free,
                :p_off,  31,
                :p_free, 1
    end

    class BcfInfo < ::FFI::BitStruct
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
        :_vptr_off_free, :uint32, # bitfields
        :len,            :int

      bitfields :_vptr_off_free,
                :vptr_off, 31,
                :vptr_free, 1
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
        :transl,         [:pointer, 2],
        :nsamples_ori,   :int,
        :keep_samples,   :pointer,
        :mem,            KString,
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
        :n_flt,          :int,
        :flt,            :pointer,
        :id,             :string,
        :als,            :pointer, # (\\0-separated string)
        :allele,         :pointer,
        :info,           BcfInfo.ptr,
        :fmt,            BcfFmt.ptr,
        :var,            Variant.ptr,
        :n_var,          :int,
        :var_type,       :int,
        :shared_dirty,   :int,
        :indiv_dirty,    :int
    end

    class Bcf1 < ::FFI::BitStruct
      layout \
        :pos,            :hts_pos_t,
        :rlen,           :hts_pos_t,
        :rid,            :int32_t,
        :qual,           :float,
        :_n_info_allele, :uint32_t,
        :_n_fmt_sample,  :uint32_t,
        :shared,         KString,
        :indiv,          KString,
        :d,              BcfDec,
        :max_unpack,     :int,
        :unpacked,       :int,
        :unpack_size,    [:int, 3],
        :errcode,        :int

      bitfields :_n_info_allele,
                :n_info,   16,
                :n_allele, 16

      bitfields :_n_fmt_sample,
                :n_fmt,    8,
                :n_sample, 24
    end
  end
end
