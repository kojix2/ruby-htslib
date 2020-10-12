# frozen_string_literal: true

module HTS
  module FFI
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
      [:void],
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
      [Kstring, BcfHdr, Bcf1],
      :int

    attach_function \
      :vcf_open_mode,
      %i[string string string],
      :int

    attach_function \
      :vcf_format,
      [BcfHdr, Bcf1, Kstring],
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
      [HtsFile, Kstring],
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
      [BcfHdr, :int, Kstring],
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
      [BcfHrec, Kstring],
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
      [Kstring, :int, :int, :pointer],
      :int

    attach_function \
      :bcf_fmt_sized_array,
      [Kstring, :pointer],
      :uint8_t

    attach_function \
      :bcf_enc_vchar,
      [Kstring, :int, :string],
      :int

    attach_function \
      :bcf_enc_vint,
      [Kstring, :int, :pointer, :int],
      :int

    attach_function \
      :bcf_enc_vfloat,
      [Kstring, :int, :pointer],
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
