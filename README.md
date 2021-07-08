# ruby-htslib

[![Gem Version](https://badge.fury.io/rb/htslib.svg)](https://badge.fury.io/rb/htslib)
![CI](https://github.com/kojix2/ruby-htslib/workflows/CI/badge.svg)
[![The MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![DOI](https://zenodo.org/badge/247078205.svg)](https://zenodo.org/badge/latestdoi/247078205)
[![Docs Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rubydoc.info/gems/htslib)

:dna: [HTSlib](https://github.com/samtools/htslib) - high-throughput sequencing data manipulation - for Ruby

:apple: Feel free to fork it out if you can develop it! 

:bowtie: alpha stage.

## Requirements

* [htslib](https://github.com/samtools/htslib)
  * Ubuntu : `apt install libhts-dev`
  * macOS : `brew install htslib`

## Installation

```sh
gem install htslib
```

If you installed htslib with Ubuntu/apt or Mac/homebrew, [pkg-config](https://github.com/ruby-gnome/pkg-config) will automatically detect the location of the shared library.

Or you can set the environment variable `HTSLIBDIR`.

```sh
export HTSLIBDIR="/your/path/to/htslib" # libhts.so
```

## Usage

### Low level API

HTS::LibHTS

```ruby
require 'htslib'

a = HTS::LibHTS.hts_open("a.bam", "r")
b = HTS::LibHTS.hts_get_format(a)
p b[:category]
p b[:format]
```

Note: Managed struct is not used in ruby-htslib. You may need to free the memory by yourself.

### High level API

A high-level API based on [hts-python](https://github.com/quinlan-lab/hts-python) or [hts-nim](https://github.com/brentp/hts-nim) is under development. We will change and improve the API to make it better.

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

[c2ffi](https://github.com/rpav/c2ffi) : 
I am trying to find a way to automatically generate a low-level API using c2ffi.

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
