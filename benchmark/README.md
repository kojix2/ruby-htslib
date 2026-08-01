# Performance plan benchmark

Run the complete low-allocation benchmark from the repository root:

```sh
bundle exec ruby benchmark/performance_plan.rb
```

Use `ITERATIONS` for record-local operations and `SCAN_ITERATIONS` for file
scans. To retain machine-readable results, set `BENCHMARK_CSV`:

```sh
ITERATIONS=100000 SCAN_ITERATIONS=100 \
  BENCHMARK_CSV=benchmark/results.csv \
  bundle exec ruby benchmark/performance_plan.rb
```

The output records elapsed time, allocated Ruby objects, the Ruby allocator's
malloc-byte delta, GC time, and resident-memory delta. Run once with the native
extension on the load path and once without it to compare the C implementation
against the native extension. Results depend on Ruby, HTSlib, compiler,
CPU, and input data, so generated CSV files are not committed as canonical
numbers.
