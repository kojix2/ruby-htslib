# FUNC_REPORT

## bgzf

```diff
1c1
< count attach_function
---
> count HTSLIB_EXPORT
```

## cram

```diff
1c1
< count attach_function
---
> count HTSLIB_EXPORT
2a3,50
> cram_fd_get_header
> cram_fd_set_header
> cram_fd_get_version
> cram_fd_set_version
> cram_major_vers
> cram_minor_vers
> cram_fd_get_fp
> cram_fd_set_fp
> cram_container_get_length
> cram_container_set_length
> cram_container_get_num_blocks
> cram_container_set_num_blocks
> cram_container_get_landmarks
> cram_container_set_landmarks
> cram_container_is_empty
> cram_block_get_content_id
> cram_block_get_comp_size
> cram_block_get_uncomp_size
> cram_block_get_crc32
> cram_block_get_data
> cram_block_get_content_type
> cram_block_set_content_id
> cram_block_set_comp_size
> cram_block_set_uncomp_size
> cram_block_set_crc32
> cram_block_set_data
> cram_block_append
> cram_block_update_size
> cram_block_get_offset
> cram_block_set_offset
> cram_block_size
> cram_transcode_rg
> cram_copy_slice
> cram_new_block
> cram_read_block
> cram_write_block
> cram_free_block
> cram_uncompress_block
> cram_compress_block
> cram_new_container
> cram_free_container
> cram_read_container
> cram_write_container
> cram_store_container
> cram_container_size
> cram_open
> cram_dopen
> cram_close
3a52,59
> cram_flush
> cram_eof
> cram_set_option
> cram_set_voption
> cram_set_header
> cram_check_EOF
> int32_put_blk
> cram_get_refs
```

## faidx

```diff
1c1
< count attach_function
---
> count HTSLIB_EXPORT
```

## hfile

```diff
1,2c1,2
< count attach_function
< 13
---
> count HTSLIB_EXPORT
> 16
15a16,18
> hfile_list_schemes
> hfile_list_plugins
> hfile_has_plugin
```

## hts

```diff
1,3c1,3
< count attach_function
< 52
< hts_get_log_level
---
> count HTSLIB_EXPORT
> 74
> hts_resize_array_
11a12,14
> hts_features
> hts_test_feature
> hts_feature_string
12a16
> hts_detect_format2
28a33
> hts_set_filter_expression
44a50,51
> hts_idx_seqnames
> hts_idx_nseq
53c60,76
< hts_idx_seqnames
---
> hts_itr_multi_bam
> hts_itr_multi_cram
> hts_itr_regions
> hts_itr_multi_next
> hts_reglist_create
> hts_reglist_free
> hts_file_type
> errmod_init
> errmod_destroy
> errmod_cal
> probaln_glocal
> hts_md5_init
> hts_md5_update
> hts_md5_final
> hts_md5_reset
> hts_md5_hex
> hts_md5_destroy
```

## kfunc

```diff
1c1
< count attach_function
---
> count HTSLIB_EXPORT
```

## sam

```diff
1,2c1,2
< count attach_function
< 102
---
> count HTSLIB_EXPORT
> 113
94a95,96
> bam_plp_constructor
> bam_plp_destructor
95a98
> bam_plp_insertion_mod
102a106,107
> bam_mplp_constructor
> bam_mplp_destructor
104a110,115
> hts_base_mod_state_alloc
> hts_base_mod_state_free
> bam_parse_basemod
> bam_mods_at_next_pos
> bam_next_basemod
> bam_mods_at_qpos
```

## tbx

```diff
1c1
< count attach_function
---
> count HTSLIB_EXPORT
```

## vcf

```diff
1,2c1,2
< count attach_function
< 85
---
> count HTSLIB_EXPORT
> 86
27a28
> bcf_hdr_combine
```

