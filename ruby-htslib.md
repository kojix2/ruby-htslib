---
title: '`hts.cr` and `ruby-htslib`: HTSlib interfaces for Crystal and Ruby'
tags:
  - bioinformatics
  - genomics
  - HTSlib
  - BAM
  - VCF
  - Crystal
  - Ruby
authors:
  - name: kojix2
    # orcid: 0000-0000-0000-0000  <!-- TODO: add ORCID -->
    affiliation: 1
    corresponding: true
affiliations:
  - name: Independent researcher
    index: 1
date: 2 August 2026
bibliography: ruby-htslib.bib
---

# Summary

`HTSlib` is the C library underlying `samtools` and `bcftools` for reading and
writing common sequencing formats [@Bonfield2021HTSlib;
@Danecek2021SAMtools]. `hts.cr` and `ruby-htslib` make this functionality
available from Crystal and Ruby. Both libraries support the principal workflows
for SAM/BAM/CRAM, VCF/BCF, indexed reference sequences (Faidx), Tabix files,
and pileups. `hts.cr` additionally exposes a BGZF reader and writer. They
expose file, header, and record objects with similar names and control flow,
allowing genomic processing code to be written in either a scripting-oriented
Ruby environment or an ahead-of-time compiled Crystal program.

The implementations are deliberately different. `ruby-htslib` 0.5 uses a
native Ruby C extension linked directly to the system HTSlib; the former
Ruby-FFI backend, exposed pointer API, and runtime library-switching mechanism
have been removed. `hts.cr` uses Crystal's native FFI declarations, with a
small companion module (`LibHTS2`) for HTSlib operations implemented as C
macros that cannot be called through the FFI. The common contribution is
therefore not a shared binding generator, but two runtime-specific
implementations of a related high-level API.

# Statement of need

Command-line tools remain the best choice for many standard transformations.
A library interface is useful when an analysis requires record-level decisions,
application state, custom data structures, interactive inspection, or direct
integration into another program. Without a maintained binding, Ruby and
Crystal users must either communicate with subprocesses or write
format-specific native code themselves.

Python, Nim, Rust, and C++ already have mature HTSlib interfaces, including
`pysam`, `cyvcf2`, `hts-nim`, `rust-htslib`, and `vcfpp`
[@pysam; @Pedersen2017cyvcf2; @Pedersen2018htsnim; @rust_htslib;
@Li2024vcfpp]. Ruby also has earlier work in BioRuby and `bio-samtools`
[@Goto2010BioRuby; @RamirezGonzalez2012BioSamtools;
@Etherington2015BioSamtools2]. The present libraries address a narrower need:
continued access to modern HTSlib from Ruby and Crystal, with alignment and
variant formats under related APIs. They do not introduce new file formats or
algorithms.

# Software design

At the high level, both libraries represent an HTS file as an object that owns
a header and yields reusable record objects. They provide typed access to BAM
auxiliary tags and BCF INFO and FORMAT fields, writing APIs, region queries,
Faidx and Tabix operations, pileup operations, and, in `hts.cr`, a public
BGZF API. Block-scoped opening provides deterministic cleanup.

Indexes for BAM/CRAM, VCF/BCF, and Tabix files are loaded when the file is
opened or on the first indexed operation, depending on the implementation.
Sequential iteration does not require an index. In `ruby-htslib`, the index is
loaded lazily on the first indexed operation such as a region query,
region-limited pileup, or sequence-name lookup; an explicit index path can
instead be validated and loaded when the file is opened. In `hts.cr`, the
index is loaded on open when an index file is present, but its absence is not
an error---sequential iteration proceeds without one.

The Ruby implementation places ownership-sensitive work in typed native
handles managed by the Ruby C API. File operations, record access, and
lifecycle management are backed by the compiled extension, which links to the
installed HTSlib, while Ruby methods provide the public object model. For
large BCF scans, borrowed genotype and numeric-vector views permit values to
be consumed without constructing genotype strings or nested arrays.
Materializing methods remain available when ownership is more important than
allocation cost.

The Crystal implementation binds HTSlib directly and wraps its pointers in
statically typed objects with finalizers and explicit close paths. HTSlib macros
that cannot be called through the FFI are represented separately in `LibHTS2`.
Crystal exposes the same broad file and record model while retaining direct
access to the native declarations for operations not yet covered at the high
level.

Both repositories include tests against real HTSlib data, executable examples,
and continuous integration on Ubuntu, macOS, and Windows. Across the two
repositories, the examples include BAM and BCF writing, tag statistics,
hard-clip summaries, pileups, modified bases, and Tabix queries. The libraries
are usable foundations rather than complete wrappers for every HTSlib routine;
uncommon mutation operations, advanced CRAM features, API consistency between
the two languages, and selected allocation-heavy convenience methods remain
areas for continued work.

# Performance evaluation

All three implementations were built and run on the same machine (2 vCPUs,
8 GB RAM, Ubuntu 26.04 LTS) against the same HTSlib installation
(`libhts-dev` 1.22.1+ds2-1), so the comparison reflects binding overhead
rather than differences in the underlying C library. Language toolchains were
Crystal 1.21.0 (LLVM 20.1.8, `--release` build), Ruby 3.3.8 with the
native-extension backend compiled via `rake compile`, and gcc 15.2.0
(`-O2`) for the C baseline. All three benchmark programs are single-threaded
and were run without file-system caching differences (inputs are small
enough to be fully page-cached after the first run).

Input data is synthetic and identical across all three programs: a
coordinate-sorted, indexed BAM file with 300,000 100 bp single-end-style
records over a 2 Mbp reference (about 15x mean depth, no indels), and an
indexed BCF file with 50,000 sites and 20 samples carrying GT, DP, AD, and GL
FORMAT fields. The indexed-region and pileup workloads use the same
arbitrary 100 kb window (`chr1:500,000-600,000`, 14,902 overlapping reads).
Pileup base counting applies a minimum base quality of 13 and no mapping
quality filter in all three implementations. Each workload was run 5 times
per implementation; the table reports the median throughput. Generator and
benchmark scripts (`gen_sam.rb`, `gen_vcf.rb`, `bench_c.c`, `bench_cr.cr`,
`bench_ruby.rb`) are available alongside this manuscript for reproduction.

| Workload | C/HTSlib | `hts.cr` | `ruby-htslib` | Notes |
|---|---:|---:|---:|---|
| Sequential BAM record scan | 2,274,000/s | 2,263,000/s | 1,282,000/s | records/s; no field conversion |
| BAM scan with flag and coordinate access | 2,279,000/s | 2,212,000/s | 1,008,000/s | common filtering path |
| Sequential BCF record scan | 1,304,000/s | 1,327,000/s | 779,000/s | site fields only |
| FORMAT/GT integer traversal | 1,169,000/s | 1,067,000/s | 41,000/s | borrowed/raw path; no strings |
| FORMAT/GT string conversion | 355,000/s | 268,000/s | 21,000/s | allocating convenience path |
| FORMAT/DP and FORMAT/AD traversal | 1,010,000/s | 928,000/s | 32,000/s | scalar and vector access |
| Indexed region query (first / repeated x20 avg) | 2,006,000 / 2,068,000/s | 2,003,000 / 2,061,000/s | 1,228,000 / 1,308,000/s | 14,902-record window |
| Pileup base counting | 5,634,000 columns/s | 1,264,000 columns/s | 102,000 columns/s | min base quality 13; all three agree exactly on the 1,017,916 bases counted |

The general pattern is consistent with the languages' respective FFI
designs. For workloads dominated by raw HTSlib calls with little
post-processing (sequential BAM/BCF scans, integer FORMAT access, indexed
region queries), `hts.cr` tracks the C baseline within about 10% (0.2-9.6%
slower, and marginally faster on the BCF scan), consistent with Crystal's
compiled, statically-typed C bindings. Its compiled-but-managed model shows
more overhead once results must be turned into individually reified objects:
GT string conversion, which allocates one `String` per sample, is about 32%
slower than C, and pileup base counting, where each pileup entry is wrapped
in a small `Alignment` object rather than accessed by array index the way
the C baseline does, is about 4.5x slower. `ruby-htslib`'s native extension
keeps sequential-scan and indexed-query overhead to about 1.6-2.3x of C, but
interpreted-language and object-allocation costs dominate workloads that
materialise many small Ruby objects per record: per-sample FORMAT/GT integer
traversal and FORMAT/DP+AD traversal are about 28-32x slower than C, GT
string conversion is about 17x slower, and pileup base counting is about
55x slower. The integer GT and DP/AD workloads use `ruby-htslib`'s
low-allocation iterator or borrowed-view paths, whereas GT string conversion
and pileup base counting use allocating convenience methods
(`genotype_strings` and `each_base_counts`). The existing
`benchmark/performance_plan.rb` micro-benchmarks provide more focused
comparisons between the owning and borrowed APIs within Ruby itself.

<!-- Optional memory table:

| Workload | C peak RSS | hts.cr peak RSS | ruby-htslib peak RSS | Allocations |
|---|---:|---:|---:|---:|
| FORMAT/GT traversal |  |  |  |  |
| Pileup base counting |  |  |  |  |
-->

These numbers characterise one synthetic dataset on modest hardware and
should be read as an indication of relative overhead rather than an
absolute performance guarantee on production workloads or larger files.

# Research impact statement

The libraries provide maintained HTSlib access to two relatively small language
communities. `ruby-htslib` has been distributed through RubyGems over multiple
releases, while `hts.cr` is distributed as a Crystal shard
[@rubyhtslib_v050; @htscr_v030]. `hts.cr` is also used by other software in the
BioCrystal organisation, including `bam-filter`, a command-line tool that
filters BAM/CRAM files with simple expressions, and `bamboo`, an example BAM
viewer built with hts.cr and libui-ng [@bam_filter; @bamboo]. These uses show
that the libraries can support both command-line analysis tools and
interactive applications.

<!-- TODO: Before submission, name at least one public analysis, dataset,
     paper, or substantial application built on these interfaces and explain
     what the binding enabled. This is the strongest justification for
     publication in JOSS. -->

Development of `ruby-htslib` received partial support from the Ruby Association
Grant 2020 [@ruby_association_grant].

# AI usage disclosure

Generative AI tools were used for source review and manuscript editing. All
claims and code-related descriptions were checked by the author against the
repositories, tests, and HTSlib documentation.

<!-- TODO: Before submission, list the exact tool, model version, dates, and
     scope of any AI-assisted code generation or review, according to JOSS
     policy. -->

# Acknowledgements

The author thanks the developers of HTSlib, SAMtools, BCFtools, Ruby, Crystal,
and the associated bioinformatics communities. The funder had no role in the
software design or decision to submit. The author declares no competing
interests.

# References
