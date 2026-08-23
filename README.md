# ruby-htslib

[![Gem Version](https://badge.fury.io/rb/htslib.svg)](https://badge.fury.io/rb/htslib)
[![test](https://github.com/kojix2/ruby-htslib/actions/workflows/ci.yml/badge.svg)](https://github.com/kojix2/ruby-htslib/actions/workflows/ci.yml)
[![The MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![DOI](https://zenodo.org/badge/247078205.svg)](https://zenodo.org/badge/latestdoi/247078205)
[![Docs Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rubydoc.info/gems/htslib)

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/kojix2/ruby-htslib)
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Fruby-htslib%2Flines)](https://tokei.kojix2.net/github/kojix2/ruby-htslib)

Ruby-htslib is the [Ruby](https://www.ruby-lang.org) bindings to [HTSlib](https://github.com/samtools/htslib), a C library for high-throughput sequencing data formats. It allows you to read and write file formats commonly used in genomics, such as [SAM, BAM, VCF, and BCF](http://samtools.github.io/hts-specs/), in the Ruby language.

:apple: Feel free to fork it!

## Requirements

- [Ruby](https://github.com/ruby/ruby) 3.1 or above.
- [HTSlib](https://github.com/samtools/htslib), including headers and `pkg-config` metadata
  - Ubuntu : `apt install libhts-dev`
  - macOS : `brew install htslib`
  - Windows : [mingw-w64-htslib](https://packages.msys2.org/base/mingw-w64-htslib) is automatically fetched when installing the gem ([RubyInstaller](https://rubyinstaller.org) only).

## Installation

```sh
gem install htslib
```

The gem builds a native extension and links to the system HTSlib. `pkg-config`
normally finds it automatically. For a non-standard installation, set
`PKG_CONFIG_PATH`, pass `--with-htslib-dir`, or set `HTSLIBDIR` while installing.

```sh
gem install htslib -- --with-htslib-dir=/your/htslib/prefix
```

RubyInstaller installs the declared MSYS2 HTSlib dependency on Windows.

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

With a block

```ruby
HTS::Bam.open("test/fixtures/moo.bam") do |bam|
  bam.each do |r|
    puts r.to_s
  end
end
```

Creating a BAM file from Ruby values

```ruby
header = HTS::Bam::Header.new
header.update_hd(version: "1.6", sort_order: "unsorted")
header.add_sq("chr1", length: 1_000_000)

record = HTS::Bam::Record.new(
  header,
  qname: "read1",
  chrom: "chr1",       # resolved through the header
  pos: 99,              # zero-based
  mapq: 60,
  cigar: "4M",
  sequence: "ACGT",
  qualities: [30, 31, 32, 33],
  aux: { "NM" => 0 }
)

HTS::Bam.open("output.bam", "wb") do |bam|
  bam.write_header(header)
  bam << record
end
```

Use `quality_string:` for a Phred+33 string instead of numeric `qualities:`.
Omit qualities (or pass `nil`) to write missing qualities. `seq:` / `qual:`
are accepted as concise aliases. Reference names can also be assigned with
`record.chrom=` and `record.mate_chrom=`.

BAM/CRAM, BCF/VCF, and Tabix indexes are loaded lazily when an indexed
operation such as `query` or a region-limited pileup first needs them. Pass an
explicit `index:` path to `open` to validate and load that index immediately.
`index_loaded?` reports whether the index is currently loaded.

### HTS::Bcf - VCF / BCF - Variant Call Format file

Reading fields

```ruby
require 'htslib'

bcf = HTS::Bcf.open("test/fixtures/test.bcf")

bcf.each do |r|
  p chrom:  r.chrom,
    pos:    r.pos + 1, # VCF POS is 1-based; Record#pos is 0-based.
    id:     r.id,
    qual:   r.qual.round(2),
    ref:    r.ref,
    alt:    r.alt,
    filters: r.filter,
    info:   r.info.to_h,
    format: r.format.to_h
end

bcf.close
```

With a block

```ruby
HTS::Bcf.open("test/fixtures/test.bcf") do |bcf|
  bcf.each do |r|
    puts r.to_s
  end
end
```

### HTS::Faidx - FASTA / FASTQ - Nucleic acid sequence

```ruby
fa = HTS::Faidx.open("test/fixtures/moo.fa")
fa.seq("chr1:1-10") # => CGCAACCCGA # 1-based
fa.close
```

### HTS::Tabix - GFF / BED - TAB-delimited genome position file

```ruby
tb = HTS::Tabix.open("test/fixtures/test.vcf.gz")
# Numeric coordinates are 0-based, half-open: [2000, 3000).
tb.query("poo", 2000, 3000) do |line|
  puts line.join("\t")
end
tb.close
```

### Low-allocation traversal

Large scans can avoid per-sample arrays and genotype strings:

```ruby
HTS::Bcf.open("variants.bcf", samples: %w[S1 S2], unpack: :format) do |bcf|
  bcf.each do |record|
    record.format.each_genotype do |sample_index, genotype|
      genotype.each_allele do |allele, phased, missing|
        # Consume the primitive values here.
      end
    end

    record.format.each_i32("DP") { |sample_index, depth| }
    record.format.each_i32_vector("AD") { |sample_index, values| values.each { |depth| } }
    record.format.each_f32_vector("GL") { |sample_index, values| values.each { |likelihood| } }
  end
end
```

The genotype and numeric vector objects yielded by these iterators are borrowed
and reused. Consume them inside the block, or call `to_s` / `to_a` to retain an
owning value. Reading a different FORMAT key does not invalidate a view; reading
the same key again makes an old view raise `InvalidBorrowedViewError` instead of
silently returning overwritten data. `genotype_strings`, `get`, and `[]` remain
the allocating convenience APIs. Use `unpack: :site_only` when FORMAT columns
are not needed.

Tabix likewise lets callers avoid splitting unused columns. All yielded Ruby
strings and arrays below are owning values:

```ruby
tb.each_line("chr1:1-1000") { |line| }
tb.each_fields("chr1:1-1000") { |fields| }
tb.each_selected_fields("chr1:1-1000", 0, 3, 4) { |values| }
```

### Native backend migration

Version 0.5 uses a compiled extension for every supported high-level API. The
former low-level binding, pointer, and runtime library-switching APIs were
implementation details and have been removed. Native handles are not exposed;
install failures report the missing HTSlib build requirement.

### Need more speed?

Try Crystal. [HTS.cr](https://github.com/bio-cr/hts.cr) is implemented in Crystal language and provides an API compatible with ruby-htslib. 

## Documentation

- [Examples](examples/)
- [API Documentation (develop branch)](https://kojix2.github.io/ruby-htslib/)
- [API Documentation (released gem)](https://rubydoc.info/gems/htslib)
- Draft paper: [EN](https://kojix2.github.io/ruby-htslib/paper/ruby-htslib.pdf) [JA](https://kojix2.github.io/ruby-htslib/paper/ruby-htslib-ja.pdf)

## Development

#### Build the extension

Install the system HTSlib development package first, then:

```sh
git clone https://github.com/kojix2/ruby-htslib
cd ruby-htslib
bundle install
bundle exec rake test
```

Use `bundle exec rake test:local` for fixture-only tests and
`bundle exec rake test:remote` for the network-dependent URI suite.

#### Use the latest Ruby

Use Ruby 3 or newer to take advantage of new features. This is possible because we have a small number of users.

#### Keep compatibility with Crystal language

Compatibility with Crystal language is important for Ruby-htslib development. 

- [HTS.cr](https://github.com/bio-cr/hts.cr) - HTSlib bindings for Crystal

Return value

The most challenging part is the return value. In the Crystal language, methods are expected to return only one type. On the other hand, in the Ruby language, methods that return multiple classes are very common. For example, in the Crystal language, the compiler gets confused if the return value is one of six types: Int32, Int64, Float32, Float64, Nil, or String. In fact Crystal allows you to do that. But the code gets a little messy. In Ruby, this is very common and doesn't cause any problems.

#### Naming convention

If you are not sure about the naming of a method, follow the Rust-htslib API. This is a very weak rule. if a more appropriate name is found later in Ruby, it will replace it.

## Contributing

Ruby-htslib is a library under development, so even minor improvements like typo fixes are welcome! Please feel free to send us your pull requests.

- [Report bugs](https://github.com/kojix2/ruby-htslib/issues)
- Fix bugs and [submit pull requests](https://github.com/kojix2/ruby-htslib/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
- [financial contributions](https://github.com/sponsors/kojix2)

```markdown
# Ownership and Commit Rights

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
