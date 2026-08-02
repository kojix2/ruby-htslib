import argparse
import re
import statistics
from collections import defaultdict
from pathlib import Path


def parse_log(path):
    data = defaultdict(list)
    with path.open(encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^(.+?)\s{2,}([\d.]+)s\s+([\d]+) records/s \(n=(\d+)\)", line)
            if m:
                label = m.group(1).strip()
                seconds = float(m.group(2))
                rate = int(m.group(3))
                n = int(m.group(4))
                data[label].append((seconds, rate, n))
    return data


parser = argparse.ArgumentParser(description="Aggregate benchmark log medians")
parser.add_argument("--c-log", type=Path, default=Path(__file__).with_name("c_runs.log"))
parser.add_argument("--cr-log", type=Path, default=Path(__file__).with_name("cr_runs.log"))
parser.add_argument("--ruby-log", type=Path, default=Path(__file__).with_name("ruby_runs.log"))
args = parser.parse_args()

files = {
    "C/HTSlib": args.c_log,
    "hts.cr": args.cr_log,
    "ruby-htslib": args.ruby_log,
}

results = {}
for impl, path in files.items():
    results[impl] = parse_log(path)

# Collect all labels in first-seen order from C log
labels = list(results["C/HTSlib"].keys())

print(f"{'Workload':<52} {'C/HTSlib':>16} {'hts.cr':>16} {'ruby-htslib':>16}")
for label in labels:
    row = [label]
    for impl in ["C/HTSlib", "hts.cr", "ruby-htslib"]:
        runs = results[impl].get(label, [])
        if not runs:
            row.append("N/A")
            continue
        rates = [r[1] for r in runs]
        median_rate = statistics.median(rates)
        row.append(f"{median_rate:,.0f}")
    print(f"{row[0]:<52} {row[1]:>16} {row[2]:>16} {row[3]:>16}")

print()
print("=== Detailed stats (median seconds, median records/s, n) ===")
for label in labels:
    print(f"\n{label}")
    for impl in ["C/HTSlib", "hts.cr", "ruby-htslib"]:
        runs = results[impl].get(label, [])
        if not runs:
            print(f"  {impl}: N/A")
            continue
        secs = [r[0] for r in runs]
        rates = [r[1] for r in runs]
        n = runs[0][2]
        print(f"  {impl:<14} median={statistics.median(secs):.4f}s  rate={statistics.median(rates):,.0f}/s  "
              f"min={min(secs):.4f}s max={max(secs):.4f}s  n={n}  runs={len(runs)}")
