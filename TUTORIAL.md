# Tutorial

```mermaid
classDiagram
Bam~Hts~ o-- `Bam::Header`
Bam o-- `Bam::Record`
Bcf~Hts~ o-- `Bcf::Header`
Bcf o-- `Bcf::Record`
`Bam::Header` o-- `Bam::HeaderRecord`
`Bcf::Header` o-- `Bcf::HeaderRecord`
`Bam::Record` o-- Flag
`Bam::Record` o-- Cigar
`Bam::Record` o-- Aux
`Bcf::Record` o-- Info
`Bcf::Record` o-- Format
class Bam{
  +@hts_file : FFI::Struct
  each()
}
class Bcf{
  +@hts_file : FFI::Struct
  each()
}
class Tbx~Hts~{
  +@hts_file : FFI::Struct
}
class `Bam::Header`{
  +@sam_hdr : FFI::Struct
}
class `Bam::Record` {
  +@bam1 : FFI::Struct
  +tid()
  +tid=()
  +mtid()
  +mtid=()
  +pos()
  +pos=()
  +mpos()
  +mpos=()
  +bin()
  +bin=()
  +endpos
}
class `Bcf::Header`{
  +@bcf_hdr : FFI::Struct
}
class `Bcf::Record`{
  +@bcf1 : FFI::Struct
}
class Flag {
  +@value : Integer
  +to_s()
}
class Cigar {
  +each()
}
class Faidx{
  +@fai
}

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
HTS::Bam.open("test/fixtures/moo.bam") do |b|
  b.each do |r|
    # ...
  end
end
```

Writing

```ruby
in = HTS::Bam.open("foo.bam")
out = HTS::Bam.open("bar.bam", "wb")

out.header = in.header
in.each do |r|
  out << r
end

in.close
out.close
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
HTS::Bcf.open("b.bcf") do |b|
  b.each do |r|
    # ...
  end
end
```

Writing

```ruby
in = HTS::Bcf.open("foo.bcf")
out = HTS::Bcf.open("bar.bcf", "wb")

out.header = in.header
in.each do |r|
  out << r
end

in.close
out.close
```
