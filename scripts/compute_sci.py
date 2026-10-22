"""Recompute SCI from saved traces, without importing or running experiment code.

Standard library only. See analysis/sci_20261022/README.md for scope and assumptions.
All raw inputs and earlier analysis outputs are read-only.
"""

import argparse
import csv
from datetime import datetime
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "analysis/sci_20261022"
PROCESSING = Path("analysis/portable_reproduced_20261018_01/processing")


def read_csv(path):
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def sha256(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def historical_byte_match(path, expected_hash):
    """Recognize the documented CRLF-to-LF Git checkout conversion exactly."""
    raw = path.read_bytes()
    current = hashlib.sha256(raw).hexdigest()
    crlf = hashlib.sha256(raw.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")).hexdigest()
    return current, current == expected_hash or crlf == expected_hash


def close(actual, expected, label):
    if not math.isclose(actual, float(expected), rel_tol=1e-10, abs_tol=1e-6):
        raise ValueError(f"{label}: {actual} != historical {expected}")


def integrate_trace(path, remove_duplicate):
    """Use Time in ms, GPU power in mW and CPU package cumulative joules.

    Retain the later sample at registered initial duplicate timestamps. The
    discarded CPU initialization jump is diagnostic, not a timed energy interval.
    """
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.reader(handle)
        fields = next(reader)
        indexes = [fields.index(k) for k in (
            "Time", "CPU_ENERGY (J)", "GPU0_POWER (mWatts)", "GPU1_POWER (mWatts)"
        )]

        def extract(row):
            values = tuple(float(row[i]) for i in indexes)
            if any(not math.isfinite(v) or v < 0 for v in values):
                raise ValueError(f"Invalid energy sample in {path}")
            return values

        first, second = extract(next(reader)), extract(next(reader))
        duplicate = first[0] == second[0]
        if duplicate != remove_duplicate:
            raise ValueError(f"Initialization registry disagrees with {path}")
        initialization_j = second[1] - first[1] if duplicate else 0.0
        if initialization_j < 0:
            raise ValueError(f"Negative CPU initialization increment in {path}")
        start = second if duplicate else first
        previous = start
        gpu0_j = gpu1_j = 0.0
        count = 2

        def increment(left, right):
            dt = right[0] - left[0]
            if dt <= 0 or right[1] < left[1]:
                raise ValueError(f"Time or CPU counter anomaly in {path}")
            return ((left[2] + right[2]) * dt / 2e6,
                    (left[3] + right[3]) * dt / 2e6)

        if not duplicate:
            gpu0_j, gpu1_j = increment(first, second)
            previous = second
        for raw in reader:
            current = extract(raw)
            e0, e1 = increment(previous, current)
            gpu0_j += e0
            gpu1_j += e1
            previous = current
            count += 1
    return {
        "sampling_start_ms": start[0], "sampling_end_ms": previous[0],
        "duration_s": (previous[0] - start[0]) / 1000,
        "gpu0_j": gpu0_j, "gpu1_j": gpu1_j,
        "gpu_j": gpu0_j + gpu1_j, "cpu_j": previous[1] - start[1],
        "excluded_cpu_initialization_j": initialization_j, "raw_samples": count,
    }


def validate_parameters(p):
    for key in ("grid_g_co2e_per_kwh", "other_hardware_w", "embodied_kg_co2e"):
        if not math.isfinite(p[key]) or p[key] < 0:
            raise ValueError(f"Invalid {key}")
    for key in ("expected_life_years", "hours_per_year", "calibration_power_multiplier"):
        if not math.isfinite(p[key]) or p[key] <= 0:
            raise ValueError(f"Invalid {key}")
    if not 0 < p["power_supply_efficiency"] <= 1:
        raise ValueError("Power supply efficiency must be in (0, 1]")
    if not 0 < p["resource_share"] <= 1 or not math.isfinite(p["pue"]) or p["pue"] < 1:
        raise ValueError("Invalid resource share or PUE")


def carbon(component_j, duration_s, p):
    """The grid factor already includes grid T&D; do not apply T&D again."""
    energy = (component_j + p["other_hardware_w"] * duration_s) / 3.6e6
    energy *= p["pue"] / p["power_supply_efficiency"]
    operational = energy * p["grid_g_co2e_per_kwh"]
    embodied = (p["embodied_kg_co2e"] * 1000 * duration_s
                / (p["expected_life_years"] * p["hours_per_year"] * 3600)
                * p["resource_share"])
    return {"facility_kwh": energy, "operational_g_co2e": operational,
            "embodied_g_co2e": embodied, "total_g_co2e": operational + embodied}


def aggregate(rows, p):
    seconds = math.fsum(x["duration_s"] for x in rows)
    joules = math.fsum(x["component_j"] for x in rows)
    return {"duration_s": seconds, "cpu_gpu_j": joules,
            "cpu_gpu_kwh": joules / 3.6e6, **carbon(joules, seconds, p)}


def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def compute(root, p):
    validate_parameters(p)
    inputs = set()

    def source(relative):
        inputs.add(Path(relative))
        return root / relative

    manifest = read_csv(source("results/main/manifest.csv"))
    calibration = read_csv(source("results/calibration/manifest.csv"))
    settings = json.loads(source("results/main/experiment.json").read_text())
    cal_settings = json.loads(source("results/calibration/experiment.json").read_text())
    if cal_settings["energy"] or cal_settings["cooldown_s"] or cal_settings["warmup_s"]:
        raise ValueError("Calibration assumptions differ from recorded settings")
    if cal_settings["settings_fingerprint"] != settings["settings_fingerprint"]:
        raise ValueError("Calibration and evaluation configuration mismatch")
    registry = {x["run_id"]: x["duplicate_time"] == "1" for x in read_csv(source(
        "analysis/portable_20261018/static/initialization_registry.csv"))}
    historical = {x["run_id"]: x for x in read_csv(source(PROCESSING / "run_reconciliation.csv"))}
    if len(manifest) != 55 or len(calibration) != 6 or len(historical) != 55:
        raise ValueError("Expected 55 main and six calibration runs")
    if {x["run_id"] for x in manifest} != set(registry) or set(registry) != set(historical):
        raise ValueError("Run identities disagree")
    ledger, checks = [], []
    for run in manifest:
        rid = run["run_id"]
        if run["status"] != "done" or run["exit_code"] != "0":
            raise ValueError(f"Unfinished run {rid}")
        energy_path = Path(run["run_dir"]) / "energy.csv"
        trace = integrate_trace(source(energy_path), registry[rid])
        old = historical[rid]
        for key, old_key in (("gpu_j", "gpu_trapezoid_window_j"), ("cpu_j", "cpu_window_j"),
                             ("sampling_start_ms", "sampling_start_ms"),
                             ("sampling_end_ms", "sampling_end_ms"),
                             ("excluded_cpu_initialization_j", "excluded_cpu_initialization_j"),
                             ("raw_samples", "raw_energy_samples")):
            close(trace[key], old[old_key], f"{rid}/{key}")
        n_queries = n_correct = 0
        if run["kind"] == "run":
            queries = read_csv(source(Path(run["run_dir"]) / "queries.csv"))
            if len(queries) != 200 or any(q["error"] for q in queries):
                raise ValueError(f"Unexpected query count/errors for {rid}")
            n_queries = len(queries)
            n_correct = sum(q["correct"].lower() == "true" for q in queries)
            close(n_correct / n_queries, run["accuracy"], f"{rid}/accuracy")
        label = "evaluation_sampled" if run["kind"] == "run" else "idle_sampled"
        record = {"stage": label, "run_id": rid, "benchmark": run["benchmark"],
                  "strategy": run["router"], "n_queries": n_queries, "n_correct": n_correct,
                  "duration_s": trace["duration_s"], "component_j": trace["gpu_j"] + trace["cpu_j"],
                  "energy_evidence": "measured_cpu_package_and_two_gpu_boards",
                  "cpu_j": trace["cpu_j"], "gpu_j": trace["gpu_j"]}
        ledger.append(record)
        process_s = (float(run["ended_at_ms"]) - float(run["started_at_ms"])) / 1000
        edge_s = process_s - trace["duration_s"]
        if edge_s < 0:
            raise ValueError(f"Sampling exceeds process time for {rid}")
        ledger.append({**record, "stage": "main_process_edges", "n_queries": 0, "n_correct": 0,
                       "duration_s": edge_s,
                       "component_j": record["component_j"] / record["duration_s"] * edge_s,
                       "energy_evidence": "modeled_at_same_run_mean_power", "cpu_j": "", "gpu_j": ""})
        current_hash, byte_match = historical_byte_match(root / energy_path, old["source_energy_sha256"])
        if not byte_match:
            raise ValueError(f"Raw bytes differ beyond documented newline conversion: {rid}")
        checks.append({"run_id": rid, **trace,
                       "historical_gpu_j": float(old["gpu_trapezoid_window_j"]),
                       "historical_cpu_j": float(old["cpu_window_j"]), "numerical_replay_pass": True,
                       "historical_source_sha256": old["source_energy_sha256"],
                       "current_source_sha256": current_hash,
                       "historical_bytes_match_after_newline_conversion": byte_match})
    main = [x for x in ledger if x["stage"] == "evaluation_sampled"]
    idle = [x for x in ledger if x["stage"] == "idle_sampled"]
    if len(main) != 50 or len(idle) != 5 or sum(x["n_queries"] for x in main) != 10000:
        raise ValueError("Unexpected experimental design")
    grouped = {}
    for x in main:
        grouped.setdefault((x["benchmark"], x["strategy"]), []).append(x)
    for c in calibration:
        if c["status"] != "done" or c["exit_code"] != "0":
            raise ValueError("Incomplete calibration")
        observed = grouped[(c["benchmark"], c["router"])]
        mean_w = math.fsum(x["component_j"] for x in observed) / math.fsum(x["duration_s"] for x in observed)
        seconds = float(c["duration_s"])
        ledger.append({"stage": "calibration_modeled", "run_id": c["run_id"],
                       "benchmark": c["benchmark"], "strategy": c["router"],
                       "n_queries": int(c["n_queries"]), "n_correct": "", "duration_s": seconds,
                       "component_j": mean_w * seconds * p["calibration_power_multiplier"],
                       "energy_evidence": "modeled_at_matching_evaluation_mean_power",
                       "cpu_j": "", "gpu_j": ""})
    idle_w = math.fsum(x["component_j"] for x in idle) / math.fsum(x["duration_s"] for x in idle)
    active_w = math.fsum(x["component_j"] for x in main) / math.fsum(x["duration_s"] for x in main)
    cooldown_s = len(manifest) * settings["cooldown_s"]
    created_ms = datetime.fromisoformat(settings["created_at"]).timestamp() * 1000
    setup_s = (min(float(x["started_at_ms"]) for x in manifest) - created_ms) / 1000 - settings["cooldown_s"]
    if setup_s < 0:
        raise ValueError("Invalid initial setup duration")
    for stage, seconds, watts, evidence in (
        ("cooldown_modeled", cooldown_s, idle_w, "configured_main_cooldowns_at_measured_idle_power"),
        ("initial_setup_modeled", setup_s, active_w, "recorded_initial_elapsed_time_at_evaluation_mean_power"),
    ):
        ledger.append({"stage": stage, "run_id": "", "benchmark": "", "strategy": "",
                       "n_queries": 0, "n_correct": "", "duration_s": seconds, "component_j": seconds * watts,
                       "energy_evidence": evidence, "cpu_j": "", "gpu_j": ""})
    stages = []
    for stage in dict.fromkeys(x["stage"] for x in ledger):
        subset = [x for x in ledger if x["stage"] == stage]
        stages.append({"stage": stage, "n_records": len(subset),
                       "n_queries": sum(x["n_queries"] for x in subset), **aggregate(subset, p)})
    strategies = []
    for (benchmark, strategy), subset in sorted(grouped.items()):
        totals = aggregate(subset, p)
        n = sum(x["n_queries"] for x in subset)
        correct = sum(x["n_correct"] for x in subset)
        strategies.append({"benchmark": benchmark, "strategy": strategy, "repetitions": len(subset),
                           "n_queries": n, "n_correct": correct, "accuracy": correct / n,
                           **totals, "sci_g_co2e_per_query": totals["total_g_co2e"] / n})
    for x in strategies:
        baseline = next(y for y in strategies if y["benchmark"] == x["benchmark"] and y["strategy"] == "large_only")
        x["relative_sci_change_pct_vs_large"] = 100 * (x["sci_g_co2e_per_query"] / baseline["sci_g_co2e_per_query"] - 1)
        x["accuracy_difference_pp_vs_large"] = 100 * (x["accuracy"] - baseline["accuracy"])
    scopes = {
        "evaluation_sampled": main,
        "main_sampled_including_idle": main + idle,
        "main_protocol_subtotal": [x for x in ledger if x["stage"] != "calibration_modeled"],
        "recorded_campaign_subtotal": ledger,
    }
    totals = {k: aggregate(v, p) for k, v in scopes.items()}
    for v in totals.values():
        v["sci_g_co2e_per_evaluation_query"] = v["total_g_co2e"] / 10000
    # Continuous reservation replaces all modeled main gaps; it never adds
    # nominal cooldowns a second time. This is a scenario, not observed ownership.
    elapsed_main_s = (max(float(x["ended_at_ms"]) for x in manifest) - created_ms) / 1000
    extra_s = elapsed_main_s - totals["main_protocol_subtotal"]["duration_s"]
    if extra_s < 0:
        raise ValueError("Main allocation exceeds elapsed experiment time")
    continuous = [{"duration_s": extra_s, "component_j": extra_s * idle_w}]
    totals["campaign_if_main_continuously_reserved"] = aggregate(ledger + continuous, p)
    totals["campaign_if_main_continuously_reserved"]["sci_g_co2e_per_evaluation_query"] = (
        totals["campaign_if_main_continuously_reserved"]["total_g_co2e"] / 10000)
    sensitivities = []
    changes = [
        ("central", {}), ("grid_244_excluding_grid_infrastructure", {"grid_g_co2e_per_kwh": 244}),
        ("grid_100", {"grid_g_co2e_per_kwh": 100}), ("grid_400", {"grid_g_co2e_per_kwh": 400}),
        ("pue_1", {"pue": 1}), ("pue_1_5", {"pue": 1.5}),
        ("other_hardware_15w", {"other_hardware_w": 15}), ("other_hardware_60w", {"other_hardware_w": 60}),
        ("embodied_500kg", {"embodied_kg_co2e": 500}), ("embodied_1500kg", {"embodied_kg_co2e": 1500}),
        ("lifespan_3y", {"expected_life_years": 3}), ("lifespan_6y", {"expected_life_years": 6}),
        ("calibration_power_minus_25pct", {"calibration_power_multiplier": .75}),
        ("calibration_power_plus_25pct", {"calibration_power_multiplier": 1.25}),
        ("combined_low", {"grid_g_co2e_per_kwh": 100, "pue": 1, "other_hardware_w": 15,
                          "power_supply_efficiency": .95, "embodied_kg_co2e": 500, "expected_life_years": 6,
                          "calibration_power_multiplier": .75}),
        ("combined_high", {"grid_g_co2e_per_kwh": 400, "pue": 1.5, "other_hardware_w": 60,
                           "power_supply_efficiency": .85, "embodied_kg_co2e": 1500, "expected_life_years": 3,
                           "calibration_power_multiplier": 1.25}),
    ]
    for name, change in changes:
        alternative = {**p, **change}
        alt_ledger = [{**x, "component_j": x["component_j"] * (
            alternative["calibration_power_multiplier"] / p["calibration_power_multiplier"]
            if x["stage"] == "calibration_modeled" else 1)} for x in ledger]
        sensitivities.append({"scenario": name, **{k: alternative[k] for k in (
            "grid_g_co2e_per_kwh", "other_hardware_w", "power_supply_efficiency", "pue",
            "embodied_kg_co2e", "expected_life_years", "calibration_power_multiplier")},
            **aggregate(alt_ledger, alternative)})
    provenance = [{"path": str(path), "sha256": sha256(root / path),
                   "bytes": (root / path).stat().st_size} for path in sorted(inputs)]
    summary = {"parameters": p, "functional_units": {
        "evaluation": "one executed held-out benchmark query, including all router/model calls",
        "campaign": "one recorded campaign subtotal, R=1; alternatively allocate its carbon over 10000 held-out query executions",
        "distinct_held_out_questions": 400, "executed_held_out_queries": 10000,
        "executed_calibration_queries": 3600},
        "measured_cpu_j": math.fsum(x["cpu_j"] for x in main + idle),
        "measured_gpu_j": math.fsum(x["gpu_j"] for x in main + idle),
        "idle_cpu_gpu_mean_w": idle_w, "evaluation_cpu_gpu_mean_w": active_w,
        "main_elapsed_s": elapsed_main_s, "unallocated_main_gap_s": extra_s,
        "scopes": totals, "raw_trace_checks_passed": len(checks),
        "raw_hashes_different_from_historical": sum(x["current_source_sha256"] != x["historical_source_sha256"] for x in checks),
        "missing_query_tail_ms": math.fsum(float(x["missing_query_end_ms"]) for x in historical.values()),
        "excluded_initialization_j": math.fsum(x["excluded_cpu_initialization_j"] for x in checks),
        "limitations": ["Annual Dutch grid factor and physical Netherlands location assumption.",
            "Additional hardware power, PSU efficiency, cooling and whole-machine LCA proxy are modeled.",
            "Recorded campaign is a subtotal: unlogged model loading, downloads, router fitting, additional warmups/retries, development, analysis and report-writing are unquantified.",
            "Continuous reservation across timestamp gaps is unknown; shown separately.",
            "A 2 ms query tail is unmetered; no extrapolation is added to sampled-window totals.",
            "Five repetitions reuse the same questions; no independent-query or causal claim follows."]}
    for x in ledger:
        x.update(carbon(x["component_j"], x["duration_s"], p))
    return summary, ledger, stages, strategies, sensitivities, checks, provenance


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--parameters", type=Path, default=DEFAULT_OUTPUT / "parameters.json")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output.resolve()
    # Protect raw inputs and historical reproduction evidence from output misuse.
    for protected in (root / "results", root / "data", root / "artifacts", root / "scripts",
                      root / "analysis/portable_reproduced_20261018_01",
                      root / "analysis/portable_20261018"):
        if output == protected or protected in output.parents:
            raise ValueError(f"Output would overwrite protected inputs: {output}")
    result = compute(root, json.loads(args.parameters.read_text()))
    summary, ledger, stages, strategies, sensitivities, checks, provenance = result
    output.mkdir(parents=True, exist_ok=True)
    (output / "summary.json").write_text(json.dumps(summary, indent=2, allow_nan=False) + "\n")
    for filename, rows in (("ledger.csv", ledger), ("stage_summary.csv", stages),
                           ("strategy_summary.csv", strategies), ("sensitivity.csv", sensitivities),
                           ("raw_trace_checks.csv", checks), ("input_hashes.csv", provenance)):
        write_csv(output / filename, rows)
    for scope, v in summary["scopes"].items():
        print(f"{scope}: {v['total_g_co2e'] / 1000:.6f} kgCO2e; {v['facility_kwh']:.6f} kWh")
    print(f"Verified {len(checks)} raw energy traces; output: {output}")


if __name__ == "__main__":
    main()
