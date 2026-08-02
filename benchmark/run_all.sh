#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

REGION=${REGION:-chr1:500000-600000}
N=${N:-5}
BAM_PATH=${BAM_PATH:-$SCRIPT_DIR/bench.bam}
BCF_PATH=${BCF_PATH:-$SCRIPT_DIR/bench.bcf}
HTS_CR_DIR=${HTS_CR_DIR:-$PROJECT_DIR/../hts.cr}
RUBY=${RUBY:-ruby}

if [[ ! $N =~ ^[1-9][0-9]*$ ]]; then
  echo "N must be a positive integer: $N" >&2
  exit 1
fi

for input in "$BAM_PATH" "$BCF_PATH"; do
  if [[ ! -f "$input" ]]; then
    echo "Missing benchmark input: $input" >&2
    exit 1
  fi
done

for command_name in cc pkg-config crystal python3 "$RUBY"; do
  if ! command -v "$command_name" >/dev/null; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

if [[ ! -f "$HTS_CR_DIR/src/hts.cr" ]]; then
  echo "Missing hts.cr checkout: $HTS_CR_DIR (override with HTS_CR_DIR)" >&2
  exit 1
fi

read -r -a HTSLIB_FLAGS <<< "$(pkg-config --cflags --libs htslib)"
cc -O2 -Wall -Wextra -o "$SCRIPT_DIR/bench_c" "$SCRIPT_DIR/bench_c.c" \
  "${HTSLIB_FLAGS[@]}"

CRYSTAL_PATH="$HTS_CR_DIR/src${CRYSTAL_PATH:+:$CRYSTAL_PATH}" \
  crystal build --release -o "$SCRIPT_DIR/bench_cr" "$SCRIPT_DIR/bench_cr.cr"

"$RUBY" -e 'require "htslib"' || {
  echo "The selected Ruby cannot load ruby-htslib" >&2
  exit 1
}

cd "$SCRIPT_DIR"

echo "=== C baseline ($N runs) ==="
for ((i = 1; i <= N; i++)); do
  echo "--- run $i ---"
  ./bench_c "$BAM_PATH" "$BCF_PATH" "$REGION"
done > c_runs.log 2>&1
cat c_runs.log

echo "=== hts.cr ($N runs) ==="
for ((i = 1; i <= N; i++)); do
  echo "--- run $i ---"
  ./bench_cr "$BAM_PATH" "$BCF_PATH" "$REGION"
done > cr_runs.log 2>&1
cat cr_runs.log

echo "=== ruby-htslib ($N runs) ==="
for ((i = 1; i <= N; i++)); do
  echo "--- run $i ---"
  "$RUBY" "$SCRIPT_DIR/bench_ruby.rb" "$BAM_PATH" "$BCF_PATH" "$REGION"
done > ruby_runs.log 2>&1
cat ruby_runs.log

python3 "$SCRIPT_DIR/aggregate.py"
