# FUNC_REPORT

## bgzf

```diff
1c1
< count attach_function: 30
---
> count HTSLIB_EXPORT: 30
```

## cram

```diff
1c1
< count attach_function: 63
---
> count HTSLIB_EXPORT: 74
15a16,17
> cram_container_get_num_records
> cram_container_get_num_bases
22a25,26
> cram_block_get_method
> cram_expand_method
32a37,38
> cram_codec_get_content_ids
> cram_codec_describe
34a41,46
> cram_decode_compression_header
> cram_free_compression_header
> cram_update_cid2ds_map
> cram_cid2ds_query
> cram_cid2ds_free
> cram_describe_encodings
46d57
< cram_compress_block2
```

## faidx

```diff
0a1,27
> count HTSLIB_EXPORT: 26
> fai_build3
> fai_build
> fai_destroy
> fai_load3
> fai_load
> fai_load3_format
> fai_load_format
> fai_fetch
> fai_fetch64
> fai_line_length
> fai_fetchqual
> fai_fetchqual64
> faidx_fetch_nseq
> faidx_fetch_seq
> faidx_fetch_seq64
> faidx_fetch_qual
> faidx_fetch_qual64
> faidx_has_seq
> faidx_nseq
> faidx_iseq
> faidx_seq_len64
> faidx_seq_len
> fai_parse_region
> fai_adjust_region
> fai_set_cache_size
> fai_path
```

## hfile

```diff
1c1
< count attach_function: 16
---
> count HTSLIB_EXPORT: 22
8a9
> hgetc2
11a13,17
> hread2
> hputc2
> hputs2
> hwrite2
> hfile_set_blksize
```

## hts

```diff
1,3c1,2
< count attach_function: 75
< hts_set_log_level
< hts_get_log_level
---
> count HTSLIB_EXPORT: 77
> hts_resize_array_
10a10,12
> seq_nt16_table[256]
> seq_nt16_str[]
> seq_nt16_int[]
```

## kfunc

```diff
1c1
< count attach_function: 6
---
> count HTSLIB_EXPORT: 6
```

## sam

```diff
1c1,2
< count attach_function: 115
---
> count HTSLIB_EXPORT: 119
> bam_cigar_table[256]
70a72,73
> bam_aux_first
> bam_aux_next
80a84
> bam_aux_remove
```

## tbx

```diff
1c1,2
< count attach_function: 12
---
> count HTSLIB_EXPORT: 13
> tbx_conf_vcf
```

## vcf

```diff
1c1,3
< count attach_function: 91
---
> count HTSLIB_EXPORT: 93
> bcf_type_shift[]
> bcf_strerror
```

