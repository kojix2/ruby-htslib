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
1,2c1,2
< count attach_function
< 58
---
> count HTSLIB_EXPORT
> 57
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
1,4c1,3
< count attach_function
< 75
< hts_set_log_level
< hts_get_log_level
---
> count HTSLIB_EXPORT
> 74
> hts_resize_array_
66a66
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

