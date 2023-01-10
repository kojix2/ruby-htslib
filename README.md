# ruby-htslib

[![Gem Version](https://badge.fury.io/rb/htslib.svg)](https://badge.fury.io/rb/htslib)
![CI](https://github.com/kojix2/ruby-htslib/workflows/CI/badge.svg)
[![The MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![DOI](https://zenodo.org/badge/247078205.svg)](https://zenodo.org/badge/latestdoi/247078205)
[![Docs Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rubydoc.info/gems/htslib)

Ruby-htslib is the [Ruby](https://www.ruby-lang.org) bindings to [HTSlib](https://github.com/samtools/htslib), a C library for high-throughput sequencing data formats. It allows you to read and write file formats commonly used in genomics, such as [SAM, BAM, VCF, and BCF](http://samtools.github.io/hts-specs/), in the Ruby language.

:apple: Feel free to fork it!

## Requirements

- [Ruby](https://github.com/ruby/ruby) 3.1 or above.
- [HTSlib](https://github.com/samtools/htslib)
  - Ubuntu : `apt install libhts-dev`
  - macOS : `brew install htslib`
  - Windows : [mingw-w64-htslib](https://packages.msys2.org/base/mingw-w64-htslib) is automatically fetched when installing the gem ([RubyInstaller](https://rubyinstaller.org) only).
  - Build from source code (see Development section)

## Installation

```sh
gem install htslib
```

If you have installed htslib with apt on Ubuntu or homebrew on Mac, [pkg-config](https://github.com/ruby-gnome/pkg-config)
will automatically detect the location of the shared library. If pkg-config does not work well, set `PKG_CONFIG_PATH`.
Alternatively, you can specify the directory of the shared library by setting the environment variable `HTSLIBDIR`.

```sh
export HTSLIBDIR="/your/path/to/htslib" # Directory where libhts.so is located
```

ruby-htslib also works on Windows. if you use RubyInstaller, htslib will be prepared automatically.

## Usage

### HTS::Bam - SAM / BAM / CRAM - Sequence Alignment Map file

Reading fields

```ruby
require 'htslib'

bam = HTS::Bam.open("test/fixtures/moo.bam")

bam.each do |r|
  pp name: r.qname,
     flag: r.flag,
     chrm: r.chrom,
     strt: r.pos + 1,
     mapq: r.mapq,
     cigr: r.cigar.to_s,
     mchr: r.mate_chrom,
     mpos: r.mpos + 1,
     isiz: r.isize,
     seqs: r.seq,
     qual: r.qual_string,
     MC:   r.aux("MC")
end

bam.close
```

### HTS::Bcf - VCF / BCF - Variant Call Format file

Reading fields

```ruby
bcf = HTS::Bcf.open("b.bcf")

bcf.each do |r|
  p chrom:  r.chrom,
    pos:    r.pos,
    id:     r.id,
    qual:   r.qual.round(2),
    ref:    r.ref,
    alt:    r.alt,
    filter: r.filter,
    info:   r.info.to_h,
    format: r.format.to_h
end

bcf.close
```

### HTS::Faidx - FASTA / FASTQ - Nucleic acid sequence

```ruby
fa = HTS::Faidx.open("c.fa")
fa.seq("chr1:1-10")
```

### HTS::Tabix - GFF / BED - TAB-delimited genome position file

```ruby
tb = HTS::Tabix.open("test.vcf.gz")
tb.query("chr1", 10000, 20000) do |line|
  p line
end
```

Note: Faidx or Tabix should not be explicitly closed. See [#27](https://github.com/kojix2/ruby-htslib/issues/27)

### Low-level API

`HTS::LibHTS` provides native C functions.

```ruby
require 'htslib'

a = HTS::LibHTS.hts_open("a.bam", "r")
b = HTS::LibHTS.hts_get_format(a)
p b[:category]
p b[:format]
```

#### Macro functions

HTSlib is designed to improve performance with many macro functions. However, it is not possible to call C macro functions directly from Ruby-FFI. To overcome this, important macro functions have been re-implemented in Ruby, allowing them to be called in the same way as native functions.

#### Garbage Collection and Memory Freeing

A small number of commonly used structs, such as Bam1 and Bcf1, are implemented using FFI's ManagedStruct. This allows for automatic memory release when Ruby's garbage collection is triggered. On the other hand, other structs are implemented using FFI::Struct, and they will require manual memory release.

### Need more speed?

Try Crystal. [HTS.cr](https://github.com/bio-cr/hts.cr) is implemented in Crystal language and provides an API compatible with ruby-htslib. Crystal language is not as flexible as Ruby language. You can not use `eval` methods and must always be careful with the types. Writing one-time scripts in Crystal may be less fun. However, if you have a clear idea of what you want to do in your mind, have already written code in Ruby, and need to run them over and over, try creating a command line tool in Crystal. The Crystal language is as fast as the Rust and C languages. It will give you incredible power to make tools.

## Documentation

- [TUTORIAL.md](TUTORIAL.md)
- [API Documentation (develop branch)](https://kojix2.github.io/ruby-htslib/)
- [API Documentation (released gem)](https://rubydoc.info/gems/htslib)

## Development

To get started with development:

```sh
git clone --recursive https://github.com/kojix2/ruby-htslib
cd ruby-htslib
bundle install
bundle exec rake htslib:build
bundle exec rake test
```

[GNU Autotools](https://en.wikipedia.org/wiki/GNU_Autotools) is required to compile htslib.

HTSlib has many macro functions. These macro functions cannot be called from FFI and must be reimplemented in Ruby.

#### Ruby 3

Use the latest Ruby to take full advantage of its potential. This is possible because we have a small number of users.

#### Crystal compatibility

Compatibility with Crystal language is important for Ruby-htslib development. The Crystal language is extremely fast and provides the performance required for real-world genome analysis.

- [HTS.cr](https://github.com/bio-cr/hts.cr) - HTSlib bindings for Crystal

The most challenging part is the return value. In the Crystal language, methods are expected to return only one type. On the other hand, in the Ruby language, methods that return multiple classes are very common. For example, in the Crystal language, the compiler gets confused if the return value is one of six types: Int32, Int64, Float32, Float64, Nil, or String. In fact Crystal allows you to do that. But the code gets a little messy. In Ruby, this is very common and doesn't cause any problems.

Ruby and Crystal are languages that use garbage collection. However, the memory release policy for allocated C structures is slightly different: in Ruby-FFI, you can define a `self.release` method in `FFI::Struct`. This method is called when GC. So you don't have to worry about memory in high-level APIs like Bam::Record or Bcf::Record, etc. Crystal requires you to define a finalize method on each class. So you need to define it in Bam::Record or Bcf::Record.

#### Naming convention

If you have trouble naming a method, follow the Rust-htslib API. Then, if you find a more appropriate name in Ruby, replace it with it.

#### FFI Extensions

Since Ruby-FFI does not support structure bit fields, the following extensions are used

- [ffi-bitfield](https://github.com/kojix2/ffi-bitfield) - Extension of Ruby-FFI to support bitfields.

#### Automatic validation

In the `script` directory, there are several tools to help implement ruby-htslib. Scripts using c2ffi can check the coverage of htslib functions in Ruby-htslib. They are useful when new versions of htslib are released.

- [c2ffi](https://github.com/rpav/c2ffi) is a tool to create JSON format metadata from C header files.

## Contributing

Ruby-htslib is a library under development, so even minor improvements like typo fixes are welcome! Please feel free to send us your pull requests.

- [Report bugs](https://github.com/kojix2/ruby-htslib/issues)
- Fix bugs and [submit pull requests](https://github.com/kojix2/ruby-htslib/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
- [financial contributions](https://github.com/sponsors/kojix2)

```markdown
# Ownership and Commitment Rights

Do you need commit rights to the ruby-htslib repository?
Do you want to get admin rights and take over the project?
If so, please feel free to contact us @kojix2.
```

#### Why do you implement htslib in a language like Ruby, which is not widely used in bioinformatics?

One of the greatest joys of using a minor language like Ruby in bioinformatics is that nothing stops you from reinventing the wheel. Reinventing the wheel can be fun. But with languages like Python and R, where many bioinformatics masters work, there is no chance for beginners to create htslib bindings. Bioinformatics file formats, libraries, and tools are very complex, and I need to learn how to understand them. So I started to implement the HTSLib binding myself to better understand how the pioneers of bioinformatics felt when establishing the file format and how they created their tools. I hope one day we can work on bioinformatics using Ruby and Crystal languages, not to replace other languages such as Python and R, but to add new power and value to this advancing field.

## Links

- [samtools/hts-spec](https://github.com/samtools/hts-specs)
- [bioruby](https://github.com/bioruby/bioruby)

## Funding support

This work was supported partially by [Ruby Association Grant 2020](https://www.ruby.or.jp/en/news/20201022).

## License

[MIT License](https://opensource.org/licenses/MIT).
