# HTSlib

[![Gem Version](https://badge.fury.io/rb/htslib.svg)](https://badge.fury.io/rb/htslib)
![CI](https://github.com/kojix2/ruby-htslib/workflows/CI/badge.svg)
[![The MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![DOI](https://zenodo.org/badge/247078205.svg)](https://zenodo.org/badge/latestdoi/247078205)
[![Docs Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rubydoc.info/gems/htslib)

:dna: [HTSlib](https://github.com/samtools/htslib) - high-throughput sequencing data manipulation - for Ruby

:apple: Feel free to fork it out if you can develop it! 

:bowtie: Just a prototype. Pre-alpha stage.

## Requirements

* [htslib](https://github.com/samtools/htslib)
  * Ubuntu : `apt install libhts-dev`
  * macOS : `brew install htslib`

## Installation

```sh
gem install htslib
```

If you installed htslib with Ubuntu/apt or Mac/homebrew, pkg-config will automatically detect the location of the shared library.

Or you can set the environment variable `HTSLIBDIR`.

```sh
export HTSLIBDIR="/your/path/to/htslib" # libhts.so
```

## Usage

HTS::FFI - Low-level API 

```ruby
require 'htslib'

a = HTS::FFI.hts_open("a.bam", "r")
b = HTS::FFI.hts_get_format(a)
p b[:category]
p b[:format]
```

A high-level API based on [hts-python](https://github.com/quinlan-lab/hts-python) is under development.

```ruby
require 'htslib'

bam = HTS::Bam.new("a.bam")

bam.each do |aln|
  p name:  aln.qname,
    flag:  aln.flag,
    start: aln.start + 1,
    mpos:  aln.mate_pos + 1,
    mqual: aln.mapping_quality,
    seq:   aln.sequence,
    cigar: aln.cigar.to_s,
    qual:  aln.base_qualities.map { |i| (i + 33).chr }.join
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

## Contributing

Ruby-htslib is a library under development, so even small improvements like typofix are welcome! Please feel free to send us your pull requests.

* [Report bugs](https://github.com/kojix2/ruby-htslib/issues)
* Fix bugs and [submit pull requests](https://github.com/kojix2/ruby-htslib/pulls)
* Write, clarify, or fix documentation
* Suggest or add new features

## Links

* [samtools/hts-spec](https://github.com/samtools/hts-specs)
* [c2ffi](https://github.com/rpav/c2ffi)

## License

[MIT License](https://opensource.org/licenses/MIT).
