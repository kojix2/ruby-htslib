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
      alias bcf_init1    bcf_init
      alias bcf_read1    bcf_read
      alias vcf_read1    vcf_read
      alias bcf_write1   bcf_write
      alias vcf_write1   vcf_write
      alias bcf_destroy1 bcf_destroy
      alias bcf_empty1   bcf_empty
      alias vcf_parse1   vcf_parse
      alias bcf_clear1   bcf_clear
      alias vcf_format1  vcf_format

      alias bcf_open     hts_open
      alias vcf_open     hts_open
      if respond_to?(:hts_flush)
        alias bcf_flush hts_flush
        alias vcf_flush hts_flush
      end
      alias bcf_close    hts_close
      alias vcf_close    hts_close
    end

    BCF_UN_STR  = 1 # up to ALT inclusive
    BCF_UN_FLT  = 2 # up to FILTER
    BCF_UN_INFO = 4 # up to INFO
    BCF_UN_SHR  = (BCF_UN_STR | BCF_UN_FLT | BCF_UN_INFO) # all shared information
    BCF_UN_FMT  = 8 # unpack format and each sample
    BCF_UN_IND  = BCF_UN_FMT # a synonym of BCF_UN_FMT
    BCF_UN_ALL  = (BCF_UN_SHR | BCF_UN_FMT) # everything

    class << self
      # Get number of samples
      def bcf_hdr_nsamples(hdr)
        hdr[:n][BCF_DT_SAMPLE]
      end

      # Function for updating INFO fields
      def bcf_update_info_int32(hdr, line, key, values, n)
        bcf_update_info(hdr, line, key, values, n, BCF_HT_INT)
      end

      # Function for updating INFO fields
      def bcf_update_info_float(hdr, line, key, values, n)
        bcf_update_info(hdr, line, key, values, n, BCF_HT_REAL)
      end

      # Function for updating INFO fields
      def bcf_update_info_flag(hdr, line, key, string, n)
        bcf_update_info(hdr, line, key, string, n, BCF_HT_FLAG)
      end

      # Function for updating INFO fields
      def bcf_update_info_string(hdr, line, key, string)
        bcf_update_info(hdr, line, key, string, 1, BCF_HT_STR)
      end

      # Function for updating FORMAT fields
      def bcf_update_format_int32(hdr, line, key, values, n)
        bcf_update_format(hdr, line, key, values, n,
                          BCF_HT_INT)
      end

      # Function for updating FORMAT fields
      def bcf_update_format_float(hdr, line, key, values, n)
        bcf_update_format(hdr, line, key, values, n,
                          BCF_HT_REAL)
      end

      # Function for updating FORMAT fields
      def bcf_update_format_char(hdr, line, key, values, n)
        bcf_update_format(hdr, line, key, values, n,
                          BCF_HT_STR)
      end

      # Function for updating FORMAT fields
      def bcf_update_genotypes(hdr, line, gts, n)
        bcf_update_format(hdr, line, "GT", gts, n, BCF_HT_INT)
      end

      # Macro for setting genotypes correctly
      def bcf_gt_phased(idx)
        ((idx + 1) << 1 | 1)
      end

      # Macro for setting genotypes correctly
      def bcf_gt_unphased(idx)
        ((idx + 1) << 1)
      end

      # Macro for setting genotypes correctly
      def bcf_gt_missing
        0
      end

      # Macro for setting genotypes correctly
      def bcf_gt_is_missing(val)
        (val >> 1 ? 0 : 1)
      end

      # Macro for setting genotypes correctly
      def bcf_gt_is_phased(idx)
        (idx & 1)
      end

      # Macro for setting genotypes correctly
      def bcf_gt_allele(val)
        ((val >> 1) - 1)
      end

      # Conversion between alleles indexes to Number=G genotype index (assuming diploid, all 0-based)
      def bcf_alleles2gt(a, b)
        ((a) > (b) ? (a * (a + 1) / 2 + b) : (b * (b + 1) / 2 + a))
      end

      # Get INFO values
      def bcf_get_info_int32(hdr, line, tag, dst, ndst)
        bcf_get_info_values(hdr, line, tag, dst, ndst, BCF_HT_INT)
      end

      # Get INFO values
      def bcf_get_info_float(hdr, line, tag, dst, ndst)
        bcf_get_info_values(hdr, line, tag, dst, ndst, BCF_HT_REAL)
      end

      # Get INFO values
      def bcf_get_info_string(hdr, line, tag, dst, ndst)
        bcf_get_info_values(hdr, line, tag, dst, ndst, BCF_HT_STR)
      end

      # Get INFO values
      def bcf_get_info_flag(hdr, line, tag, dst, ndst)
        bcf_get_info_values(hdr, line, tag, dst, ndst, BCF_HT_FLAG)
      end

      # Get FORMAT values
      def bcf_get_format_int32(hdr, line, tag, dst, ndst)
        bcf_get_format_values(hdr, line, tag, dst, ndst, BCF_HT_INT)
      end

      # Get FORMAT values
      def bcf_get_format_float(hdr, line, tag, dst, ndst)
        bcf_get_format_values(hdr, line, tag, dst, ndst, BCF_HT_REAL)
      end

      # Get FORMAT values
      def bcf_get_format_char(hdr, line, tag, dst, ndst)
        bcf_get_format_values(hdr, line, tag, dst, ndst, BCF_HT_STR)
      end

      # Get FORMAT values
      def bcf_get_genotypes(hdr, line, dst, ndst)
        bcf_get_format_values(hdr, line, "GT", dst, ndst, BCF_HT_INT)
      end

      # Translates numeric ID into string
      def bcf_hdr_int2id(hdr, type, int_id)
        LibHTS::BcfIdpair.new(
          hdr[:id][type].to_ptr +
          LibHTS::BcfIdpair.size * int_id # offsets
        )[:key]
      end

      # Translates sequence names (chromosomes) into numeric ID
      def bcf_hdr_name2id(hdr, id)
        bcf_hdr_id2int(hdr, BCF_DT_CTG, id)
      end

      # Translates numeric ID to sequence name
      def bcf_hdr_id2name(hdr, rid)
        return nil if hdr.null? || rid < 0 || rid >= hdr[:n][LibHTS::BCF_DT_CTG]

        LibHTS::BcfIdpair.new(
          hdr[:id][LibHTS::BCF_DT_CTG].to_ptr +
          LibHTS::BcfIdpair.size * rid # offset
        )[:key]
      end

      # Macro for accessing bcf_idinfo_t
      def bcf_hdr_id2length(hdr, type, int_id)
        LibHTS::BcfIdpair.new(
          hdr[:id][LibHTS::BCF_DT_ID].to_ptr +
          LibHTS::BcfIdpair.size * int_id # offset
        )[:val][:info][type] >> 8 & 0xf
      end

      # Macro for accessing bcf_idinfo_t
      def bcf_hdr_id2number(hdr, type, int_id)
        LibHTS::BcfIdpair.new(
          hdr[:id][LibHTS::BCF_DT_ID].to_ptr +
          LibHTS::BcfIdpair.size * int_id # offset
        )[:val][:info][type] >> 12
      end

      # Macro for accessing bcf_idinfo_t
      def bcf_hdr_id2type(hdr, type, int_id)
        LibHTS::BcfIdpair.new(
          hdr[:id][LibHTS::BCF_DT_ID].to_ptr +
          LibHTS::BcfIdpair.size * int_id # offset
        )[:val][:info][type] >> 4 & 0xf
      end

      # Macro for accessing bcf_idinfo_t
      def bcf_hdr_id2coltype(hdr, type, int_id)
        LibHTS::BcfIdpair.new(
          hdr[:id][LibHTS::BCF_DT_ID].to_ptr +
          LibHTS::BcfIdpair.size * int_id # offset
        )[:val][:info][type] & 0xf
      end

      # def bcf_hdr_idinfo_exists

      # def bcf_hdr_id2hrec

      alias bcf_itr_destroy hts_itr_destroy

      def bcf_itr_queryi(idx, tid, beg, _end)
        hts_itr_query(idx, tid, beg, _end, @ffi_functions[:bcf_readrec])
      end

      @@bcf_hdr_name2id = proc do |hdr, id|
        LibHTS.bcf_hdr_name2id(hdr, id)
      end

      def bcf_itr_querys(idx, hdr, s)
        hts_itr_querys(idx, s, @@bcf_hdr_name2id, hdr, @ffi_functions[:hts_itr_query], @ffi_functions[:bcf_readrec])
      end

      # Load a BCF index
      def bcf_index_load(fn)
        hts_idx_load(fn, HTS_FMT_CSI)
      end

      # Load a BCF index
      def bcf_index_seqnames(idx, hdr, nptr)
        hts_idx_seqnames(idx, nptr, @@bcf_hdr_id2name, hdr)
      end

      # Typed value I/O
      # INT8_MIN  + 1
      def bcf_int8_vector_end  = -127
      # INT16_MIN + 1
      def bcf_int16_vector_end = -32_767
      # INT32_MIN + 1
      def bcf_int32_vector_end = -2_147_483_647
      # INT64_MIN + 1
      def bcf_int64_vector_end = -9_223_372_036_854_775_807
      def bcf_str_vector_end   = 0
      # INT8_MIN
      def bcf_int8_missing     = -128
      # INT16_MIN
      def bcf_int16_missing    = (-32_767 - 1)
      # INT32_MIN
      def bcf_int32_missing    = (-2_147_483_647 - 1)
      # INT64_MIN
      def bcf_int64_missing    = (-9_223_372_036_854_775_807 - 1)
      def bcf_str_missing      = 0x07

      BCF_MAX_BT_INT8  = 0x7f           # INT8_MAX  */
      BCF_MAX_BT_INT16 = 0x7fff         # INT16_MAX */
      BCF_MAX_BT_INT32 = 0x7fffffff     # INT32_MAX */
      BCF_MIN_BT_INT8  = -120           # INT8_MIN  + 8 */
      BCF_MIN_BT_INT16 = -32_760        # INT16_MIN + 8 */
      BCF_MIN_BT_INT32 = -2_147_483_640 # INT32_MIN + 8 */
    end
  end
end
