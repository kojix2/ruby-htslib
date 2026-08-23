# Paper benchmark

The paper benchmark requires Ruby with Bundler, Crystal, HTSlib and its
development files, SAMtools, BCFtools, a C compiler, Python 3, and a checkout of
the latest `hts.cr`. Gnuplot is used to render the paper's benchmark figure.
With `hts.cr` next to this repository, run:

```sh
git clone https://github.com/bio-cr/hts.cr ../hts.cr
bundle install
benchmark/run_all.sh
```

The script generates and indexes the synthetic BAM and BCF inputs when needed,
builds the current `ruby-htslib` and `hts.cr` checkouts, runs the C, Crystal,
and Ruby implementations five times, reports median throughput, and updates
`paper/data/benchmark-throughput.tsv` and
`paper/figures/benchmark-throughput.png`. Set
`HTS_CR_DIR` if the `hts.cr` checkout is elsewhere, or `N` to change the number
of runs.
