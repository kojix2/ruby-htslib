# Tutorial

```mermaid
%%{init:{'theme':'base'}}%%
classDiagram
Bam~Hts~ o-- `Bam::Header`
Bam o-- `Bam::Record`
`Bam::Record` o-- `Bam::Header`
Bcf~Hts~ o-- `Bcf::Header`
Bcf o-- `Bcf::Record`
`Bcf::Record` o--`Bcf::Header`
`Bam::Header` o-- `Bam::HeaderRecord`
`Bcf::Header` o-- `Bcf::HeaderRecord`
`Bam::Record` o-- Flag
`Bam::Record` o-- Cigar
`Bam::Record` o-- Aux
`Bcf::Record` o-- Info
`Bcf::Record` o-- Format
class Bam{
  +@hts_file : FFI::Struct
  +@header : Bam::Header
  +@file_name
  +@index_name
  +@mode
  +struct()
  +build_index()
  +each() Enumerable
  +query()
}
class Bcf{
  +@hts_file : FFI::Struct
  +@header : Bcf::Header
  +@file_name
  +@index_name
  +@mode
  +struct()
  +build_index()
  +each() Enumerable
  +query()
}
class Tabix~Hts~{
  +@hts_file : FFI::Struct
}
class `Bam::Header`{
  +@sam_hdr : FFI::Struct
  +struct()
  +target_count()
  +target_names()
  +name2tid()
  +tid2name()
  +to_s()
}
class `Bam::Record` {
  +@bam1 : FFI::Struct
  +@header : Bam::Header
  +struct()
  +qname()
  +qname=()
  +tid()
  +tid=()
  +mtid()
  +mtid=()
  +pos()
  +pos=()
  +mpos() +mate_pos()
  +mpos=() +mate_pos=()
  +bin()
  +bin=()
  +endpos()
  +chorm() +contig()
  +mate_chrom() +mate_contig()
  +strand()
  +mate_strand()
  +isize() +insert_size()
  +isize=() +insert_size=()
  +mapq()
  +mapq=()
  +cigar()
  +qlen()
  +rlen()
  +seq() +sequence()
  +len()
  +base(n)
  +qual()
  +qual_string()
  +base_qual(n)
  +flag()
  +flag=()
  +aux()
  +to_s()
}
class `Aux` {
  -@record : Bam::Record
  +[]()
  +get_int()
  +get_float()
  +get_string()
}
class `Bcf::Header`{
  +@bcf_hdr : FFI::Struct
  +struct()
  +to_s()
}
class `Bcf::Record`{
  +@bcf1 : FFI::Struct
  +@header : Bcf::Header
  +struct()
  +rid()
  +rid=()
  +chrom()
  +pos()
  +pos=()
  +id()
  +id=()
  +clear_id()
  +ref()
  +alt()
  +alleles()
  +qual()
  +qual=()
  +filter()
  +info()
  +format()
  +to_s()
}
class Flag {
  +@value : Integer
  +paired?()
  +proper_pair?()
  +unmapped?()
  +mate_unmapped?()
  +reverse?()
  +mate_reverse?()
  +read1?()
  +read2?()
  +secondary?()
  +qcfail?()
  +duplicate?()
  +supplementary?()
  +&()
  +|()
  +^()
  +~()
  +<<()
  +>>()
  +to_i()
  +to_s()
}
class Info {
  -@record : Bcf::Record
  +[]()
  +get_int()
  +get_float()
  +get_string()
  +get_flag()
  +fields()
  +length() +size()
  +to_h()
  -info_ptr()
}
class Format {
  -@record : Bcf::Record
  +[]()\
  +get_int()
  +get_float()
  +get_string()
  +get_flag()
  +fields()
  +length() +size()
  +to_h()
  -format_ptr()
}
class Cigar {
  -@array : Array
  +each() Enumerable
  +qlen()
  +rlen()
  +to_s()
  +==()
  +eql?()
}
class Faidx{
  +@fai
}

```

## Installation

```
gem install htslib
```

You can check which shared libraries are used by ruby-htslib as follows

```ruby
require "htslib"
puts HTS.lib_path
# => "/home/kojix2/.rbenv/versions/3.2.0/lib/ruby/gems/3.2.0/gems/htslib-0.2.6/vendor/libhts.so"
```

## HTS::Bam - SAM / BAM / CRAM - Sequence Alignment Map file

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

Open with block

```ruby
HTS::Bam.open("test/fixtures/moo.bam") do |bam|
  bam.each do |record|
    # ...
  end
end
```

Writing

```ruby
in = HTS::Bam.open("foo.bam")
out = HTS::Bam.open("bar.bam", "wb")

out.header = in.header
# out.write_header(in.header)

in.each do |r|
  out << r
  # out.write(r)
end

in.close
out.close
```

Create index

```ruby
HTS::Bam.open("foo.bam", build_index: true)
```

```
b = HTS::Bam.open("foo.bam")
            .build_index
            .load_index
```

## HTS::Bcf - VCF / BCF - Variant Call Format file

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

Open with block

```ruby
HTS::Bcf.open("b.bcf") do |bcf|
  bcf.each do |record|
    # ...
  end
end
```

Writing

```ruby
in = HTS::Bcf.open("foo.bcf")
out = HTS::Bcf.open("bar.bcf", "wb")

out.header = in.header
# out.write_header(in.header)
in.each do |r|
  out << r
  # out.write(r)
end

in.close
out.close
```
