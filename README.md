# HTSlib

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

a = HTSlib::Native.hts_open("a.bam", "r")
b = HTSlib::Native.hts_get_format(a)
p b[:category]
p b[:format]
```

## Development

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kojix2/htslib.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
