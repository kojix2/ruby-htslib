# frozen_string_literal: true

module HTS
  module LibHTS
    # constants
    BCF_HL_FLT    = 0 # header line
    BCF_HL_INFO   = 1
    BCF_HL_FMT    = 2
    BCF_HL_CTG    = 3
    BCF_HL_STR    = 4 # structured header line TAG=<A=..,B=..>
    BCF_HL_GEN    = 5 # generic header line
    BCF_HT_FLAG   = 0 # header type

    BCF_HT_INT    = 1
    BCF_HT_REAL   = 2
    BCF_HT_STR    = 3
    BCF_HT_LONG   = (BCF_HT_INT | 0x100) # BCF_HT_INT, but for int64_t values; VCF only!

    BCF_VL_FIXED  = 0 # variable length
    BCF_VL_VAR    = 1
    BCF_VL_A      = 2
    BCF_VL_G      = 3
    BCF_VL_R      = 4

    BCF_DT_ID     = 0 # dictionary type
    BCF_DT_CTG    = 1
    BCF_DT_SAMPLE = 2

    BCF_BT_NULL   = 0
    BCF_BT_INT8   = 1
    BCF_BT_INT16  = 2
    BCF_BT_INT32  = 3
    BCF_BT_INT64  = 4 # Unofficial, for internal use only.
    BCF_BT_FLOAT  = 5
    BCF_BT_CHAR   = 7

    VCF_REF       = 0
    VCF_SNP       = 1
    VCF_MNP       = 2
    VCF_INDEL     = 4
    VCF_OTHER     = 8
    VCF_BND       = 16 # breakend
    VCF_OVERLAP   = 32 # overlapping deletion, ALT=*

    BCF1_DIRTY_ID  = 1
    BCF1_DIRTY_ALS = 2
    BCF1_DIRTY_FLT = 4
    BCF1_DIRTY_INF = 8

    BCF_ERR_CTG_UNDEF   = 1
    BCF_ERR_TAG_UNDEF   = 2
    BCF_ERR_NCOLS       = 4
    BCF_ERR_LIMITS      = 8
    BCF_ERR_CHAR        = 16
    BCF_ERR_CTG_INVALID = 32
    BCF_ERR_TAG_INVALID = 64

    # macros
    class << self
      alias bcf_open hts_open
      alias vcf_open hts_open
      alias bcf_close hts_close
      alias vcf_close hts_close

      def bcf_hdr_nsamples(hdr)
        hdr[:n][BCF_DT_SAMPLE]
      end

      def bcf_update_info_int32(hdr, line, key, values, n)
        bcf_update_info(hdr, line, key, values, n, BCF_HT_INT)
      end

      def bcf_update_info_float(hdr, line, key, values, n)
        bcf_update_info(hdr, line, key, values, n, BCF_HT_REAL)
      end

      def bcf_update_info_flag(hdr, line, key, string, n)
        bcf_update_info(hdr, line, key, string, n, BCF_HT_FLAG)
      end

      def bcf_update_info_string(hdr, line, key, string)
        bcf_update_info(hdr, line, key, string, 1, BCF_HT_STR)
      end

      def bcf_update_format_int32(hdr, line, key, values, n)
        bcf_update_format(hdr, line, key, values, n,
                          BCF_HT_INT)
      end

      def bcf_update_format_float(hdr, line, key, values, n)
        bcf_update_format(hdr, line, key, values, n,
                          BCF_HT_REAL)
      end

      def bcf_update_format_char(hdr, line, key, values, n)
        bcf_update_format(hdr, line, key, values, n,
                          BCF_HT_STR)
      end

      def bcf_update_genotypes(hdr, line, gts, n)
        bcf_update_format(hdr, line, "GT", gts, n, BCF_HT_INT)
      end

      def bcf_gt_phased(idx)
        ((idx + 1) << 1 | 1)
      end

      def bcf_gt_unphased(idx)
        ((idx + 1) << 1)
      end

      def bcf_gt_missing
        0
      end

      def bcf_gt_is_missing(val)
        ((val) >> 1 ? 0 : 1)
      end

      def bcf_gt_is_phased(idx)
        ((idx) & 1)
      end

      def bcf_gt_allele(val)
        (((val) >> 1) - 1)
      end

      def bcf_alleles2gt(a, b)
        ((a) > (b) ? (a * (a + 1) / 2 + b) : (b * (b + 1) / 2 + a))
      end

      def bcf_get_info_int32(hdr, line, tag, dst, ndst)
        bcf_get_info_values(hdr, line, tag, dst, ndst, BCF_HT_INT)
      end

      def bcf_get_info_float(hdr, line, tag, dst, ndst)
        bcf_get_info_values(hdr, line, tag, dst, ndst, BCF_HT_REAL)
      end

      def bcf_get_info_string(hdr, line, tag, dst, ndst)
        bcf_get_info_values(hdr, line, tag, dst, ndst, BCF_HT_STR)
      end

      def bcf_get_info_flag(hdr, line, tag, dst, ndst)
        bcf_get_info_values(hdr, line, tag, dst, ndst, BCF_HT_FLAG)
      end

      def bcf_get_format_int32(hdr, line, tag, dst, ndst)
        bcf_get_format_values(hdr, line, tag, dst, ndst, BCF_HT_INT)
      end

      def bcf_get_format_float(hdr, line, tag, dst, ndst)
        bcf_get_format_values(hdr, line, tag, dst, ndst, BCF_HT_REAL)
      end

      def bcf_get_format_char(hdr, line, tag, dst, ndst)
        bcf_get_format_values(hdr, line, tag, dst, ndst, BCF_HT_STR)
      end

      def bcf_get_genotypes(hdr, line, dst, ndst)
        bcf_get_format_values(hdr, line, "GT", dst, ndst, BCF_HT_INT)
      end
    end

    # constants
    BCF_UN_STR  = 1 # up to ALT inclusive
    BCF_UN_FLT  = 2 # up to FILTER
    BCF_UN_INFO = 4 # up to INFO
    BCF_UN_SHR  = (BCF_UN_STR | BCF_UN_FLT | BCF_UN_INFO) # all shared information
    BCF_UN_FMT  = 8 # unpack format and each sample
    BCF_UN_IND  = BCF_UN_FMT # a synonym of BCF_UN_FMT
    BCF_UN_ALL  = (BCF_UN_SHR | BCF_UN_FMT) # everything

    attach_function \
      :bcf_hdr_init,
      [:string],
      BcfHdr.by_ref

    attach_function \
      :bcf_hdr_destroy,
      [BcfHdr],
      :void

    attach_function \
      :bcf_init,
      [],
      Bcf1.by_ref

    attach_function \
      :bcf_destroy,
      [Bcf1],
      :void

    attach_function \
      :bcf_empty,
      [Bcf1],
      :void

    attach_function \
      :bcf_clear,
      [Bcf1],
      :void

    attach_function \
      :bcf_hdr_read,
      [HtsFile],
      BcfHdr.by_ref

    attach_function \
      :bcf_hdr_set_samples,
      [BcfHdr, :string, :int],
      :int

    attach_function \
      :bcf_subset_format,
      [BcfHdr, Bcf1],
      :int

    attach_function \
      :bcf_hdr_write,
      [HtsFile, BcfHdr],
      :int

    attach_function \
      :vcf_parse,
      [KString, BcfHdr, Bcf1],
      :int

    attach_function \
      :vcf_open_mode,
      %i[string string string],
      :int

    attach_function \
      :vcf_format,
      [BcfHdr, Bcf1, KString],
      :int

    attach_function \
      :bcf_read,
      [HtsFile, BcfHdr, Bcf1],
      :int

    attach_function \
      :bcf_unpack,
      [Bcf1, :int],
      :int

    attach_function \
      :bcf_dup,
      [Bcf1],
      Bcf1.by_ref

    attach_function \
      :bcf_copy,
      [Bcf1, Bcf1],
      Bcf1.by_ref

    attach_function \
      :bcf_write,
      [HtsFile, BcfHdr, Bcf1],
      :int

    attach_function \
      :vcf_hdr_read,
      [HtsFile],
      BcfHdr.by_ref

    attach_function \
      :vcf_hdr_write,
      [HtsFile, BcfHdr],
      :int

    attach_function \
      :vcf_read,
      [HtsFile, BcfHdr, Bcf1],
      :int

    attach_function \
      :vcf_write,
      [HtsFile, BcfHdr, Bcf1],
      :int

    attach_function \
      :bcf_readrec,
      [BGZF, :pointer, :pointer, :pointer, :hts_pos_t, :hts_pos_t],
      :int

    attach_function \
      :vcf_write_line,
      [HtsFile, KString],
      :int

    attach_function \
      :bcf_hdr_dup,
      [BcfHdr],
      BcfHdr.by_ref

    attach_function \
      :bcf_hdr_merge,
      [BcfHdr, BcfHdr],
      BcfHdr.by_ref

    attach_function \
      :bcf_hdr_add_sample,
      [BcfHdr, :string],
      :int

    attach_function \
      :bcf_hdr_set,
      [BcfHdr, :string],
      :int

    attach_function \
      :bcf_hdr_format,
      [BcfHdr, :int, KString],
      :int

    attach_function \
      :bcf_hdr_fmt_text,
      [BcfHdr, :int, :pointer],
      :string

    attach_function \
      :bcf_hdr_append,
      [BcfHdr, :string],
      :int

    attach_function \
      :bcf_hdr_printf,
      [BcfHdr, :string, :varargs],
      :int

    attach_function \
      :bcf_hdr_get_version,
      [BcfHdr],
      :string

    attach_function \
      :bcf_hdr_set_version,
      [BcfHdr, :string],
      :int

    attach_function \
      :bcf_hdr_remove,
      [BcfHdr, :int, :string],
      :void

    attach_function \
      :bcf_hdr_subset,
      [BcfHdr, :int, :pointer, :pointer],
      BcfHdr.by_ref

    attach_function \
      :bcf_hdr_seqnames,
      [BcfHdr, :pointer],
      :pointer

    attach_function \
      :bcf_hdr_parse,
      [BcfHdr, :string],
      :int

    attach_function \
      :bcf_hdr_sync,
      [BcfHdr],
      :int

    attach_function \
      :bcf_hdr_parse_line,
      [BcfHdr, :string, :pointer],
      BcfHrec.by_ref

    attach_function \
      :bcf_hrec_format,
      [BcfHrec, KString],
      :int

    attach_function \
      :bcf_hdr_add_hrec,
      [BcfHdr, BcfHrec],
      :int

    attach_function \
      :bcf_hdr_get_hrec,
      [BcfHdr, :int, :string, :string, :string],
      BcfHrec.by_ref

    attach_function \
      :bcf_hrec_dup,
      [BcfHrec],
      BcfHrec.by_ref

    attach_function \
      :bcf_hrec_add_key,
      [BcfHrec, :string, :size_t],
      :int

    attach_function \
      :bcf_hrec_set_val,
      [BcfHrec, :int, :string, :size_t, :int],
      :int

    attach_function \
      :bcf_hrec_find_key,
      [BcfHrec, :string],
      :int

    attach_function \
      :hrec_add_idx,
      [BcfHrec, :int],
      :int

    attach_function \
      :bcf_hrec_destroy,
      [BcfHrec],
      :void

    attach_function \
      :bcf_subset,
      [BcfHdr, Bcf1, :int, :pointer],
      :int

    attach_function \
      :bcf_translate,
      [BcfHdr, BcfHdr, Bcf1],
      :int

    attach_function \
      :bcf_get_variant_types,
      [Bcf1],
      :int

    attach_function \
      :bcf_get_variant_type,
      [Bcf1, :int],
      :int

    attach_function \
      :bcf_is_snp,
      [Bcf1],
      :int

    attach_function \
      :bcf_update_filter,
      [BcfHdr, Bcf1, :pointer, :int],
      :int

    attach_function \
      :bcf_add_filter,
      [BcfHdr, Bcf1, :int],
      :int

    attach_function \
      :bcf_remove_filter,
      [BcfHdr, Bcf1, :int, :int],
      :int

    attach_function \
      :bcf_has_filter,
      [BcfHdr, Bcf1, :string],
      :int

    attach_function \
      :bcf_update_alleles,
      [BcfHdr, Bcf1, :pointer, :int],
      :int

    attach_function \
      :bcf_update_alleles_str,
      [BcfHdr, Bcf1, :string],
      :int

    attach_function \
      :bcf_update_id,
      [BcfHdr, Bcf1, :string],
      :int

    attach_function \
      :bcf_add_id,
      [BcfHdr, Bcf1, :string],
      :int

    attach_function \
      :bcf_update_info,
      [BcfHdr, Bcf1, :string, :pointer, :int, :int],
      :int

    attach_function \
      :bcf_update_format_string,
      [BcfHdr, Bcf1, :string, :pointer, :int],
      :int

    attach_function \
      :bcf_update_format,
      [BcfHdr, Bcf1, :string, :pointer, :int, :int],
      :int

    attach_function \
      :bcf_get_fmt,
      [BcfHdr, Bcf1, :string],
      BcfFmt.by_ref

    attach_function \
      :bcf_get_info,
      [BcfHdr, Bcf1, :string],
      BcfInfo.by_ref

    attach_function \
      :bcf_get_fmt_id,
      [Bcf1, :int],
      BcfFmt.by_ref

    attach_function \
      :bcf_get_info_id,
      [Bcf1, :int],
      BcfInfo.by_ref

    attach_function \
      :bcf_get_info_values,
      [BcfHdr, Bcf1, :string, :pointer, :pointer, :int],
      :int

    attach_function \
      :bcf_get_format_string,
      [BcfHdr, Bcf1, :string, :pointer, :pointer],
      :int

    attach_function \
      :bcf_get_format_values,
      [BcfHdr, Bcf1, :string, :pointer, :pointer, :int],
      :int

    attach_function \
      :bcf_hdr_id2int,
      [BcfHdr, :int, :string],
      :int

    attach_function \
      :bcf_fmt_array,
      [KString, :int, :int, :pointer],
      :int

    attach_function \
      :bcf_fmt_sized_array,
      [KString, :pointer],
      :uint8_t

    attach_function \
      :bcf_enc_vchar,
      [KString, :int, :string],
      :int

    attach_function \
      :bcf_enc_vint,
      [KString, :int, :pointer, :int],
      :int

    attach_function \
      :bcf_enc_vfloat,
      [KString, :int, :pointer],
      :int

    attach_function \
      :bcf_index_load2,
      %i[string string],
      HtsIdx.by_ref

    attach_function \
      :bcf_index_load3,
      %i[string string int],
      HtsIdx.by_ref

    attach_function \
      :bcf_index_build,
      %i[string int],
      :int

    attach_function \
      :bcf_index_build2,
      %i[string string int],
      :int

    attach_function \
      :bcf_index_build3,
      %i[string string int int],
      :int

    attach_function \
      :bcf_idx_init,
      [HtsFile, BcfHdr, :int, :string],
      :int

    attach_function \
      :bcf_idx_save,
      [HtsFile],
      :int
  end
end
