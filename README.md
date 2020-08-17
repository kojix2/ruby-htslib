# HTSlib

![CI](https://github.com/kojix2/ruby-htslib/workflows/CI/badge.svg?branch=master)

:apple: Feel free to fork it out if you can develop it! 

:bowtie: Just a prototype. 

## Installation

```sh
gem install htslib
```

Set environment variable HTSLIBDIR. 

```sh
export HTSLIBDIR="/your/path/to/htslib"
```

## Requirements

* [htslib](https://github.com/samtools/htslib)

## Usage

```ruby
require 'htslib'

a = HTS::FFI.hts_open("a.bam", "r")
b = HTS::FFI.hts_get_format(a)
p b[:category]
p b[:format]
```

## Development

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kojix2/ruby-htslib.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
