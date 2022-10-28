---
title: 'ruby-htslib and HTS.cr'
author:
  - 'kojix2'
  - 'Naohisa Goto'
date: 24 May 2022
bibliography: ruby-htslib.bib
header-includes:
  - \usepackage[margin=1in]{geometry}
---

# Summary

We present ruby-htslib and HTS.cr.

Ruby-htslib is the Ruby bindings to HTSlib, a C library for processing high throughput sequencing (HTS) data. It will provide APIs to read and write file formats such as SAM/BAM and VCF/BCF.

In recent years, next-generation sequencing (NGS) technologies for reading DNA and RNA sequences have become popular in the life science field. We will provide a way to manipulate the HTS file formats from Ruby.

* Code of ruby-htslib : [https://github.com/kojix2/ruby-htslib](https://github.com/kojix2/ruby-htslib)
* Code of HTS.cr : [https://github.com/bio-cr/hts.cr](https://github.com/bio-cr/hts.cr)

# Statement of need

The Ruby language is an object-oriented programming language. It is a general-purpose programming language used primarily in the field of web application development. Ruby has also been used in the bioinformatics field, and the BioRuby project [@goto2010] provides access to many file formats.

In recent years, file formats such as SAM, BAM, CRAM, VCF, and BCF have become widely used with the spread of next-generation sequencers. SAM, BAM, and CRAM are file formats for alignments, while VCF and BCF are file formats for variants. The specifications for these file formats are defined in hts-spec. Samtools and Bcftools were created to manipulate HTS files. And the core part of samtools became a library called HTSlib. We can use HTSLib to read, write and query HTS files.

Ruby-htslib is an htslib [@bonfield2021] binding that provides access to HTS files from the Ruby language and provides a means to develop bioinformatics web applications.

Bio-Samtools2 [@etherington2015]

# Benchmark

[@pedersen2018]

# Examples

# Reference
