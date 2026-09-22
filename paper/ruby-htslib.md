---
title: "`ruby-htslib` and `hts.cr`: HTSlib interfaces for Ruby and Crystal"
tags:
  - bioinformatics
  - genomics
  - HTSlib
  - sequencing
  - Crystal
  - Ruby
authors:
  - name: kojix2
date: 23 August 2026
bibliography: ruby-htslib.bib
documentclass: article
fontsize: 10pt
papersize: a4
header-includes:
  - \usepackage[a4paper,margin=24mm]{geometry}
---

# Summary

`HTSlib` is a C library for reading and writing genomic data that underlies
`samtools` and `bcftools` [@Bonfield2021HTSlib;
@Danecek2021SAMtools]. `hts.cr` and `ruby-htslib` make this functionality
available in Crystal and Ruby, respectively. Both libraries support
SAM/BAM/CRAM, VCF/BCF, indexed reference sequences (Faidx), Tabix-indexed
files, and pileup generation.

`ruby-htslib` uses a native C extension for Ruby that links directly to the
system-installed HTSlib, whereas `hts.cr` calls HTSlib through Crystal's FFI.
These libraries allow researchers and developers using Ruby or Crystal to
process genomic data within their programs without invoking external
command-line tools.

# Statement of need

Dedicated command-line tools are available for many routine genomic data
processing tasks. Research-specific analyses may, however, require selecting or
aggregating records based on combinations of fields, inspecting records
interactively, retaining results in custom data structures, or integrating the
processing with another library. Such operations may not be expressible through
existing command-line options and can require custom scripts or programs.
HTSlib provides parsing, compression, and indexed access through a C API. Using
these facilities safely from a higher-level language requires more than calling
C functions: HTSlib files, headers, records, and their lifetimes must be mapped
onto the language's data model.

Python, Nim, Rust, and C++ have mature HTSlib interfaces, including
`pysam`, `cyvcf2`, `hts-nim`, `rust-htslib`, and `vcfpp`
[@pysam; @Pedersen2017cyvcf2; @Pedersen2018htsnim; @rust_htslib;
@Li2024vcfpp]. These interfaces belong to their respective language ecosystems
and cannot be used directly in Ruby or Crystal programs. In Ruby,
`bio-samtools`, a BioRuby plugin, has provided a high-level interface for
SAMtools-based alignment processing, pileups, variant analysis, and
visualization [@Goto2010BioRuby; @RamirezGonzalez2012BioSamtools;
@Etherington2015BioSamtools2]. By contrast, `ruby-htslib` binds the standalone
HTSlib library and exposes alignment and variant files, headers, and records as
building blocks for Ruby analysis programs. `hts.cr` makes the same HTSlib
facilities available through Crystal's FFI, static type system, and native
compilation. This combination allows streaming bioinformatics tools to be
written without implementing their processing core in a second language. The
two libraries make HTSlib operations composable using idioms suited to their
respective languages.

# Software design

Both libraries represent HTSlib files, headers, and records using a shared,
record-oriented object model. This model manages the lifetimes of native
resources and distinguishes values borrowed during iteration from values that
can be retained afterward. `Bam` represents SAM/BAM/CRAM files, and `Bcf`
represents VCF/BCF files; each retains its corresponding `Header`. A file
object's `each` method yields one `Record` at a time, reusing the same object and
native buffer throughout the iteration. This approach avoids materializing the
entire file and limits allocation, but a record must be copied if it is to be
retained after the iterator advances. Record fields can be read and updated
through Ruby or Crystal methods; alignment auxiliary tags and variant INFO and
FORMAT fields are represented as typed values. Region queries and writing use
the same file, header, and record objects.

Operations with different access units are not forced into this common model.
An indexed FASTA file is represented by a `Faidx` object that retrieves
reference subsequences, whereas a Tabix-indexed text file is represented by a
`Tabix` object that returns rows overlapping a region. A pileup is not another
file format but a position-oriented view derived from `Bam`; it iterates over
reference positions and the alignments that overlap them. Each file object can
be opened with a block, ensuring that the file is closed and its native
resources are released when the block finishes.

Although the libraries share this object model, their mechanisms for exposing
borrowed values and retaining results reflect the conventions of each language.
The `ruby-htslib` C extension stores HTSlib pointers in typed Ruby objects and
registers the corresponding cleanup functions with the garbage collector.
Iteration reuses a native record buffer, whereas records and fields that must be
retained are copied into independent Ruby objects. BCF FORMAT fields can also be
accessed without copying through borrowed views of reusable buffers. Users can
therefore choose between retaining values as Ruby arrays and strings or
processing borrowed values during iteration to limit allocation.

`hts.cr` wraps HTSlib pointers in statically typed Crystal objects and expresses
the distinction between borrowed and owned data through types and block scope.
Native buffers can be exposed as block-scoped `Slice` values or borrowed views,
and primitive iterators can process fields without creating intermediate arrays
or strings. Copying only the values needed after iteration reduces heap
allocation and garbage-collection pressure. Together with Crystal's native
compilation, this design supports efficient record-by-record processing of
HTSlib data in streaming tools.

# Performance evaluation

To characterize the runtime overhead of the two libraries, we implemented
equivalent workloads in C, `hts.cr`, and `ruby-htslib` and compared their
throughput.
All three implementations used HTSlib 1.22.1-51-gcd2a6f61 and ran
single-threaded on Ubuntu 26.04 LTS. The C baseline was compiled with GCC
15.2.0 (`-O2`), `hts.cr`
0.4.0 with Crystal 1.21.0
(LLVM 20.1.8, `--release`), and `ruby-htslib` 0.6.0 with Ruby 4.0.6. The
comparison therefore reflects the costs of crossing the language boundary and
of the data representations exposed by each API, rather than differences in
HTSlib itself.

The synthetic inputs comprised a BAM file with 300,000 100-bp single-end reads
aligned to a 2-Mbp reference (approximately 15-fold mean depth) and a BCF file
with 50,000 sites for 20 samples, including GT, DP, AD, and GL FORMAT fields.
The BAM file was coordinate-sorted, and both files were indexed. Region-query
and pileup workloads used a 100-kb interval (`chr1:500,000-600,000`) overlapping
14,902 reads. Pileup base counting applied a base-quality threshold of 13 and
no mapping-quality filter. Each workload was run five times, and the
table reports the median throughput. After the first run, the input data fit in
the operating system's page cache. The scripts are included in the `benchmark`
directory.

![Median throughput relative to the C/HTSlib implementation. Region-query values are the per-query means from 20 repeats.](figures/benchmark-throughput.png){width=100%}

| Workload | C/HTSlib | `hts.cr` | `ruby-htslib` |
| --- | ---: | ---: | ---: |
| Sequential BAM record scan | 2,938,000 records/s | 3,009,000 records/s | 1,689,000 records/s |
| BAM scan with flag and coordinate access | 2,949,000 records/s | 2,895,000 records/s | 1,326,000 records/s |
| Sequential BCF record scan | 1,624,000 records/s | 1,738,000 records/s | 1,080,000 records/s |
| FORMAT/GT integer traversal | 1,425,000 records/s | 1,345,000 records/s | 54,000 records/s |
| FORMAT/GT string conversion | 438,000 records/s | 386,000 records/s | 29,000 records/s |
| FORMAT/DP and FORMAT/AD traversal | 1,357,000 records/s | 827,000 records/s | 43,000 records/s |
| Region query (first / mean of 20 repeats) | 2,622,000 / 2,674,000 records/s | 2,634,000 / 2,694,000 records/s | 1,725,000 / 1,761,000 records/s |
| Pileup base counting | 6,792,000 columns/s | 4,846,000 columns/s | 140,000 columns/s |

For sequential record scans, integer FORMAT access, and region queries,
`hts.cr` achieved 94--107% of the C throughput. Throughput was 88% of C when
converting each sample's genotype to a string, 61% for FORMAT/DP and FORMAT/AD
traversal, and 71% for pileup base counting. Thus, `hts.cr` approached C
throughput when it could process native buffers directly, while string
creation and traversal through higher-level views incurred additional costs.

`ruby-htslib` achieved 45--67% of the C throughput for sequential scans and
region queries. The gap was larger for FORMAT and pileup processing, where its
throughput was 2--7% of C. The integer GT and DP/AD workloads used an iterator
or borrowed view to limit allocations, but conversion to Ruby values and block
dispatch still occurred for individual values. GT string conversion and pileup
used `genotype_strings` and `each_base_counts`, which return owning values and
therefore include the costs of copying and object creation. All three
implementations processed the same record counts and counted the same total of
1,017,916 pileup bases.

This evaluation is intended to characterize representative execution paths in
the APIs presented here, rather than to establish a general ranking of the
languages. The measurements were obtained on one machine with one synthetic
dataset and may not predict end-to-end performance on production data or larger
files.

# Research impact statement

Within BioCrystal, `hts.cr` is used by `bam-filter`, a command-line tool that
filters BAM/CRAM files using expressions, and by `bamboo`, a BAM viewer built
with libui-ng [@bam_filter; @bamboo].

# AI usage disclosure

Codex was used in preparing this manuscript.

# Acknowledgements

Development of `ruby-htslib` received partial support from the Ruby Association
Grant 2020 [@ruby_association_grant]. The author thanks the developers of
HTSlib, SAMtools, BCFtools, Ruby, and Crystal, and the associated bioinformatics
communities. The funder had no role in the software design or decision to
submit. The author declares no competing interests.

# References
