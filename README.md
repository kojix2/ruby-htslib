# ruby-htslib

[![Gem Version](https://badge.fury.io/rb/htslib.svg)](https://badge.fury.io/rb/htslib)
![CI](https://github.com/kojix2/ruby-htslib/workflows/CI/badge.svg)
[![The MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![DOI](https://zenodo.org/badge/247078205.svg)](https://zenodo.org/badge/latestdoi/247078205)
[![Docs Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rubydoc.info/gems/htslib)

:dna: [HTSlib](https://github.com/samtools/htslib) - for Ruby

Ruby-htslib is the Ruby bindings to HTSlib, a C library for processing high throughput sequencing (HTS) data. 
It will provide APIs to read and write file formats such as [SAM, BAM, VCF, and BCF](http://samtools.github.io/hts-specs/).

:apple: Feel free to fork it out if you can develop it! 

:bowtie: alpha stage.

## Requirements

* [Ruby](https://github.com/ruby/ruby) 2.7 or above.
* [HTSlib](https://github.com/samtools/htslib)
  * Ubuntu : `apt install libhts-dev`
  * macOS : `brew install htslib`
  * Build from source code (see Development section)

## Installation

```sh
gem install htslib
```

If you have installed htslib with apt on Ubuntu or homebrew on Mac, [pkg-config](https://github.com/ruby-gnome/pkg-config) 
will automatically detect the location of the shared library. 
Alternatively, you can specify the directory of the shared library by setting the environment variable `HTSLIBDIR`.

```sh
export HTSLIBDIR="/your/path/to/htslib" # libhts.so
```

## Overview

### High level API

A high-level API is under development. 
Classes such as `Cram` `Bam` `Bcf` `Faidx` `Tabix` are partially implemented.

Read SAM / BAM - Sequence Alignment Map file

```ruby
require 'htslib'

bam = HTS::Bam.new("a.bam")

bam.each do |r|
  p name:  r.qname,
    flag:  r.flag,
    start: r.start + 1,
    mpos:  r.mate_pos + 1,
    mqual: r.mapping_quality,
    seq:   r.sequence,
    cigar: r.cigar.to_s,
    qual:  r.base_qualities.map { |i| (i + 33).chr }.join
end

bam.close
```

Read VCF / BCF - Variant Call Format

```ruby
bcf = HTS::Bcf.new("b.bcf")

bcf.each do |r|
  p chrom:  r.chrom,
    pos:    r.pos,
    id:     r.id,
    qual:   r.qual.round(2),
    ref:    r.ref,
    alt:    r.alt,
    filter: r.filter
end

bcf.close
```

The methods for reading are implemented first. Methods for writing will be implemented in the coming days.

### Low level API

`HTS::LibHTS` provides native functions. 

```ruby
require 'htslib'

a = HTS::LibHTS.hts_open("a.bam", "r")
b = HTS::LibHTS.hts_get_format(a)
p b[:category]
p b[:format]
```

Note: Only some C structs are implemented with FFI's ManagedStruct, which frees memory when Ruby's garbage collection fires. Other structs will need to be freed manually.

## Documentation

* [RubyDoc.info - HTSlib](https://rdoc.info/gems/htslib)

## Development

To get started with development

```sh
git clone --recursive https://github.com/kojix2/ruby-htslib
cd ruby-htslib
bundle install
bundle exec rake htslib:build
bundle exec rake test
```

Many macro functions are used in HTSlib. Since these macro functions cannot be called using FFI, they must be reimplemented in Ruby.

* Actively use the advanced features of Ruby.
* Consider compatibility with [htslib.cr](https://github.com/bio-crystal/htslib.cr) to some extent.

#### FFI Extensions

* [ffi-bitfield](https://github.com/kojix2/ffi-bitfield) : Extension of Ruby-FFI to support bitfields.

#### Automatic generation or automatic validation (Future plan)


+ [c2ffi](https://github.com/rpav/c2ffi) is a tool to create JSON format metadata from C header files. It is planned to use c2ffi to automatically generate bindings or tests.

## Contributing

Ruby-htslib is a library under development, so even small improvements like typofix are welcome! Please feel free to send us your pull requests.

* [Report bugs](https://github.com/kojix2/ruby-htslib/issues)
* Fix bugs and [submit pull requests](https://github.com/kojix2/ruby-htslib/pulls)
* Write, clarify, or fix documentation
* Suggest or add new features
* [financial contributions](https://github.com/sponsors/kojix2)

#### Why do you implement htslib in a language like Ruby, which is not widely used in the bioinformatics?

One of the greatest joys of using a minor language like Ruby in bioinformatics is that there is nothing stopping you from reinventing the wheel. Reinventing the wheel can be fun. But with languages like Python and R, where many bioinformatics masters work, there is no chance left for beginners to create htslib bindings. Bioinformatics file formats, libraries and tools are very complex and I don't know how to understand them. So I wanted to implement the HTSLib binding to better understand how to use the file formats and tools. And that effort is still going on today...(Translated with DeepL)

## Links

* [samtools/hts-spec](https://github.com/samtools/hts-specs)
* [bioruby](https://github.com/bioruby/bioruby)

## Funding support

This work was supported partially by [Ruby Association Grant 2020](https://www.ruby.or.jp/en/news/20201022).
## License

[MIT License](https://opensource.org/licenses/MIT).
