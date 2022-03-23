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

Read SAM / BAM / CRAM - Sequence Alignment Map file

```ruby
require 'htslib'

bam = HTS::Bam.open("a.bam")

bam.each do |r|
  p name:  r.qname,
    flag:  r.flag,
    pos:   r.start + 1,
    mpos:  r.mate_start + 1,
    mqual: r.mapping_quality,
    seq:   r.sequence,
    cigar: r.cigar.to_s,
    qual:  r.base_qualities.map { |i| (i + 33).chr }.join
  # tag:   r.tag("MC")
end

bam.close
```

Read VCF / BCF - Variant Call Format file

```ruby
bcf = HTS::Bcf.open("b.bcf")

bcf.each do |r|
  p chrom:  r.chrom,
    pos:    r.pos,
    id:     r.id,
    qual:   r.qual.round(2),
    ref:    r.ref,
    alt:    r.alt,
    filter: r.filter
  # info:   r.info
  # format: r.format
end

bcf.close
```

### Low level API

`HTS::LibHTS` provides native　C functions. 

```ruby
require 'htslib'

a = HTS::LibHTS.hts_open("a.bam", "r")
b = HTS::LibHTS.hts_get_format(a)
p b[:category]
p b[:format]
```

Note: htslib makes extensive use of macro functions for speed. you cannot use C macro functions in Ruby if they are not reimplemented in ruby-htslib. Only small number of C structs are implemented with FFI's ManagedStruct, which frees memory when Ruby's garbage collection fires. Other structs will need to be freed manually. 

### Need more speed?

Try Crystal. [htslib.cr](https://github.com/bio-crystal/htslib.cr) is implemented in Crystal language and provides an API compatible with ruby-htslib. Crsytal language is not as flexible as Ruby language. You can not use eval methods, and you must always be aware of the types. It is not very suitable for writing one-time scripts or experimenting with different code. However, If you have already written code in ruby-htslib, have a clear idea of the manipulations you want to do, and need to execute them many times, then by all means try to implement the command line tool using htslib.cr. The Crystal language is very fast and can perform almost as well as the Rust and C languages.

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
* Remain compatibile with [htslib.cr](https://github.com/bio-crystal/htslib.cr).
  * The most difficult part is the return value. In the Crystal language, it is convenient for a method to return only one type. In the Ruby language, on the other hand, it is more convenient to return multiple classes. For example, in the Crystal language, it is confusing that a return value can take four types: Int32, Float32, Nil, and String. In Ruby, on the other hand, it is very common and does not cause any problems.

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

```
Do you need commit rights to my repository?
Do you want to get admin rights and take over the project?
If so, please feel free to contact us @kojix2.
```

#### Why do you implement htslib in a language like Ruby, which is not widely used in the bioinformatics?

One of the greatest joys of using a minor language like Ruby in bioinformatics is that there is nothing stopping you from reinventing the wheel. Reinventing the wheel can be fun. But with languages like Python and R, where many bioinformatics masters work, there is no chance left for beginners to create htslib bindings. Bioinformatics file formats, libraries and tools are very complex and I don't know how to understand them. So I wanted to implement the HTSLib binding myself to better understand how the pioneers of bioinformatics felt when establishing the file format and how they created their tools. And that effort is still going on today...

## Links

* [samtools/hts-spec](https://github.com/samtools/hts-specs)
* [bioruby](https://github.com/bioruby/bioruby)

## Funding support

This work was supported partially by [Ruby Association Grant 2020](https://www.ruby.or.jp/en/news/20201022).
## License

[MIT License](https://opensource.org/licenses/MIT).
