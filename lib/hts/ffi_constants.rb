# frozen_string_literal: true

module HTS
  module FFI
    typedef :pointer, :HFILE
    typedef :int64, :hts_pos_t
    typedef :pointer, :bam_plp_auto_f

    # kstring

    class Kstring < ::FFI::Struct
      layout \
        :l,              :size_t,
        :m,              :size_t,
        :s,              :string
    end

    # BGZF
    class BGZF < ::FFI::Struct
      layout \
        :piyo1,                  :uint, # FIXME
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

    # hts
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

    BAM_CIGAR_STR = 'MIDNSHP=XB'
    BAM_CIGAR_STR_PADDED = 'MIDNSHP=XB??????'
    BAM_CIGAR_SHIFT = 4
    BAM_CIGAR_MASK  = 0xf
    BAM_CIGAR_TYPE  = 0x3C1A7

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
