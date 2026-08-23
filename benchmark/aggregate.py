import argparse
import csv
import re
import statistics
import subprocess
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
paper_dir = Path(__file__).resolve().parents[1] / "paper"
parser.add_argument(
    "--figure-data",
    type=Path,
    default=paper_dir / "data" / "benchmark-throughput.tsv",
)
parser.add_argument(
    "--figure",
    type=Path,
    default=paper_dir / "figures" / "benchmark-throughput.png",
)
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

figure_workloads = {
    "Sequential BAM record scan": "BAM scan",
    "BAM scan w/ flag+coord access": "BAM fields",
    "Sequential BCF record scan": "BCF scan",
    "FORMAT/GT integer traversal": "GT integers",
    "FORMAT/GT string conversion": "GT strings",
    "FORMAT/DP+AD traversal": "DP/AD",
    "Indexed region query (repeated x20, per-call avg)": "Region query",
    "Pileup base counting": "Pileup",
}


def median_rate(implementation, label):
    runs = results[implementation].get(label, [])
    if not runs:
        raise SystemExit(f"missing benchmark result for {implementation}: {label}")
    return statistics.median(run[1] for run in runs)


args.figure_data.parent.mkdir(parents=True, exist_ok=True)
with args.figure_data.open("w", encoding="utf-8", newline="") as handle:
    writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
    writer.writerow(["workload", "hts.cr", "ruby-htslib"])
    for label, short_label in figure_workloads.items():
        baseline = median_rate("C/HTSlib", label)
        writer.writerow(
            [
                short_label,
                f'{100 * median_rate("hts.cr", label) / baseline:.2f}',
                f'{100 * median_rate("ruby-htslib", label) / baseline:.2f}',
            ]
        )

args.figure.parent.mkdir(parents=True, exist_ok=True)
plot_script = paper_dir / "scripts" / "plot_benchmark.gnuplot"
subprocess.run(
    [
        "gnuplot",
        "-e",
        f"datafile='{args.figure_data}'; outfile='{args.figure}'",
        str(plot_script),
    ],
    check=True,
)

print(f"{'Workload':<52} {'C/HTSlib':>16} {'hts.cr':>16} {'ruby-htslib':>16}")
for label in labels:
    row = [label]
    for impl in ["C/HTSlib", "hts.cr", "ruby-htslib"]:
        runs = results[impl].get(label, [])
        if not runs:
            row.append("N/A")
            continue
        rates = [r[1] for r in runs]
        rate_median = statistics.median(rates)
        row.append(f"{rate_median:,.0f}")
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
