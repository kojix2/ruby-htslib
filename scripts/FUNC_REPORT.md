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
10a11,16
> cram_container_get_length
> cram_container_set_length
> cram_container_get_num_blocks
> cram_container_set_num_blocks
> cram_container_get_landmarks
> cram_container_set_landmarks
11a18,47
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
17a54,55
> cram_set_option
> cram_set_voption
18a57,59
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
1c1
< count attach_function
---
> count HTSLIB_EXPORT
```

## hts

```diff
1c1
< count attach_function
---
> count HTSLIB_EXPORT
3,4c3
< hts_set_log_level
< hts_get_log_level
---
> hts_resize_array_
62a62
> hts_itr_regions
65a66
> hts_file_type
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
1c1
< count attach_function
---
> count HTSLIB_EXPORT
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
1c1
< count attach_function
---
> count HTSLIB_EXPORT
27a28
> bcf_hdr_combine
```

