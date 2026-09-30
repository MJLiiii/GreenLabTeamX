"""
Run-level metrics. Mean J/query is total GPU energy divided by evaluated queries.

MMLU-Pro accuracy and GSM-Hard accuracy stay on separate rows.
"""

import argparse
import csv
import json
import sys
from pathlib import Path

from measurement.energibridge import profile_csv, summary_joules

SUMMARY_FIELDS = [
    "run_id",
    "strategy",
    "benchmark",
    "split",
    "n_queries",
    "n_correct",
    "accuracy",
    "accuracy_metric",
    "mean_latency_ms",
    "total_gpu_joules",
    "mean_j_per_query",
    "total_cpu_joules",
    "cpu_summary_joules",
    "mean_gpu_utilization_pct",
    "mean_cpu_utilization_pct",
    "peak_gpu_memory_mib",
    "peak_system_memory_bytes",
    "settings_fingerprint",
]

ACCURACY_METRIC = {
    "mmlu_pro": "multiple_choice_accuracy",
    "gsm_hard": "exact_match_extracted_number",
}

ENERGY_DEFINITION = (
    "mean_j_per_query = total_gpu_joules / n_queries; "
    "total_gpu_joules integrates GPU*_POWER (mWatts) * Delta from the "
    "EnergiBridge --gpu CSV. cpu_summary_joules is the --summary line and is CPU only."
)


def summarize_run(run_dir, hardware=None) -> dict:
    """Write summary.json for one run directory and return the scalar row."""
    run_dir = Path(run_dir)
    info = {}
    run_json = run_dir / "run.json"
    if run_json.exists():
        info = json.loads(run_json.read_text(encoding="utf-8"))

    queries = _read_csv(run_dir / "queries.csv")
    n_queries = len(queries)
    n_correct = sum(1 for row in queries if row.get("correct") == "True")
    latencies = [value for row in queries if (value := _latency_ms(row)) is not None]

    profile = profile_csv(run_dir / "energy.csv") if (run_dir / "energy.csv").exists() else {}
    total_gpu = profile.get("total_gpu_joules")
    mean_j = (total_gpu / n_queries) if total_gpu is not None and n_queries else None

    log_path = run_dir / "stdout.log"
    cpu_summary = None
    if log_path.exists():
        cpu_summary = summary_joules(log_path.read_text(encoding="utf-8"))

    benchmark = info.get("benchmark")
    router = info.get("router") or {}
    summary = {
        "run_id": info.get("run_id") or run_dir.name,
        "strategy": router.get("router"),
        "benchmark": benchmark,
        "split": info.get("split"),
        "n_queries": n_queries,
        "n_correct": n_correct,
        "accuracy": (n_correct / n_queries) if n_queries else None,
        "accuracy_metric": ACCURACY_METRIC.get(benchmark),
        "mean_latency_ms": (sum(latencies) / len(latencies)) if latencies else None,
        "total_gpu_joules": total_gpu,
        "mean_j_per_query": mean_j,
        "total_cpu_joules": profile.get("total_cpu_joules"),
        "cpu_summary_joules": cpu_summary,
        "mean_gpu_utilization_pct": profile.get("mean_gpu_utilization_pct"),
        "mean_cpu_utilization_pct": profile.get("mean_cpu_utilization_pct"),
        "peak_gpu_memory_mib": profile.get("peak_gpu_memory_mib"),
        "peak_system_memory_bytes": profile.get("peak_system_memory_bytes"),
        "settings_fingerprint": info.get("settings_fingerprint"),
        "energy_definition": ENERGY_DEFINITION,
        "configuration": {
            "settings_fingerprint": info.get("settings_fingerprint"),
            "generation": info.get("generation"),
            "max_new_tokens": info.get("max_new_tokens"),
            "router": router or None,
            "data_file": info.get("data_file"),
            "data_sha256": info.get("data_sha256"),
        },
        "hardware": hardware,
    }
    _write_json(run_dir / "summary.json", summary)
    return {field: summary.get(field) for field in SUMMARY_FIELDS}


def aggregate_experiment(exp_dir) -> list[dict]:
    """One scalar row per run. Benchmarks are not pooled into one accuracy."""
    exp_dir = Path(exp_dir)
    hardware = None
    experiment_json = exp_dir / "experiment.json"
    if experiment_json.exists():
        hardware = json.loads(experiment_json.read_text(encoding="utf-8")).get("hardware")

    rows = []
    for run_dir in sorted(path for path in exp_dir.iterdir() if path.is_dir()):
        if not (run_dir / "queries.csv").exists() and not (run_dir / "energy.csv").exists():
            continue
        rows.append(summarize_run(run_dir, hardware=hardware))

    with open(exp_dir / "aggregate.csv", "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=SUMMARY_FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    return rows


def _latency_ms(row) -> float | None:
    if row.get("latency_ms"):
        return float(row["latency_ms"])
    if row.get("latency_s"):
        return float(row["latency_s"]) * 1000.0
    return None


def _read_csv(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with open(path, newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def _write_json(path, data):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Write summary.json per run and aggregate.csv for an experiment directory."
    )
    parser.add_argument("exp_dir", type=Path)
    args = parser.parse_args(argv)
    if not args.exp_dir.is_dir():
        print(f"{args.exp_dir} is not a directory", file=sys.stderr)
        return 2
    rows = aggregate_experiment(args.exp_dir)
    print(f"Wrote {args.exp_dir / 'aggregate.csv'} ({len(rows)} runs)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
