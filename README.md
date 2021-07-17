# ruby-htslib

[![Gem Version](https://badge.fury.io/rb/htslib.svg)](https://badge.fury.io/rb/htslib)
![CI](https://github.com/kojix2/ruby-htslib/workflows/CI/badge.svg)
[![The MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![DOI](https://zenodo.org/badge/247078205.svg)](https://zenodo.org/badge/latestdoi/247078205)
[![Docs Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rubydoc.info/gems/htslib)

:dna: [HTSlib](https://github.com/samtools/htslib) - for Ruby

Ruby-htslib is the Ruby bindings to HTSlib, a C library for processing high throughput sequencing (HTS) data. 
It will provide APIs to read and write file formats such as SAM, BAM, VCF, and BCF.

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

### Low level API

`HTS::LibHTS` provides native functions. 

```ruby
require 'htslib'

a = HTS::LibHTS.hts_open("a.bam", "r")
b = HTS::LibHTS.hts_get_format(a)
p b[:category]
p b[:format]
```

Note: Managed struct is not used in ruby-htslib. You may need to free the memory by yourself.

### High level API (Plan)

`Cram` `Bam` `Bcf` `Faidx` `Tabix`

A high-level API is under development. We will change and improve the API to make it better.

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
```

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

We plan to actively use the new features of Ruby. Since the number of users is small, backward compatibility is not important.
On the other hand, we will consider compatibility with [Crystal](https://github.com/bio-crystal/htslib.cr) to some extent.

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

## Links

* [samtools/hts-spec](https://github.com/samtools/hts-specs)
* [bioruby](https://github.com/bioruby/bioruby)

## Funding support

This work was supported partially by [Ruby Association Grant 2020](https://www.ruby.or.jp/en/news/20201022).
## License

[MIT License](https://opensource.org/licenses/MIT).
