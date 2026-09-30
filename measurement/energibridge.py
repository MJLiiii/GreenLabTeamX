"""
Adapter for the EnergiBridge CLI (https://github.com/tdurieux/EnergiBridge).

    energibridge --output FILE --interval MS --max-execution SECONDS --gpu --summary -- COMMAND

`--interval` is milliseconds. `--summary` prints CPU package joules. GPU energy
is the integral of `GPU*_POWER (mWatts)` times `Delta` from the `--gpu` CSV.
This module does not load models and does not import routers.
"""

import csv
import re
from pathlib import Path

import config

SUMMARY_PATTERN = re.compile(r"Energy consumption in joules: ([\d.eE+-]+)")

_GPU_POWER = re.compile(r"GPU\d+_POWER \(mWatts\)")
_GPU_USAGE = re.compile(r"GPU\d+_USAGE")
_GPU_MEMORY = re.compile(r"GPU\d+_MEMORY_USED")
_CPU_USAGE = re.compile(r"CPU_USAGE_\d+")


def wrap(command, output_path, *, binary=None, interval_ms=None, max_seconds=None) -> list[str]:
    """Return the argv that measures `command`. The command itself must not load models."""
    binary = config.ENERGIBRIDGE["path"] if binary is None else binary
    if interval_ms is None:
        interval_ms = config.ENERGIBRIDGE["interval_ms"]
    if max_seconds is None:
        max_seconds = config.ENERGIBRIDGE["max_seconds"]
    return [
        binary,
        "--output", str(output_path),
        "--interval", str(interval_ms),
        "--max-execution", str(max_seconds),
        "--gpu",
        "--summary",
        "--",
        *command,
    ]


def summary_joules(log_text: str) -> float | None:
    """CPU joules from the `--summary` line, if EnergiBridge printed one."""
    match = None
    for match in SUMMARY_PATTERN.finditer(log_text):
        pass
    return float(match.group(1)) if match else None


def profile_csv(path) -> dict:
    """GPU joules, mean utilization, and memory peaks from an EnergiBridge CSV.

    GPU memory is in the CSV unit (MiB on the NVIDIA traces in this repo).
    USED_MEMORY is bytes, per the EnergiBridge README.
    """
    path = Path(path)
    with open(path, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = [row for row in reader if row.get("Delta")]
        fieldnames = reader.fieldnames or []

    if not rows:
        return {
            "samples": 0,
            "total_gpu_joules": None,
            "total_cpu_joules": None,
            "mean_gpu_utilization_pct": None,
            "mean_cpu_utilization_pct": None,
            "peak_gpu_memory_mib": None,
            "peak_system_memory_bytes": None,
        }

    power_cols = [name for name in fieldnames if _GPU_POWER.fullmatch(name)]
    gpu_usage_cols = [name for name in fieldnames if _GPU_USAGE.fullmatch(name)]
    gpu_memory_cols = [name for name in fieldnames if _GPU_MEMORY.fullmatch(name)]
    cpu_usage_cols = [name for name in fieldnames if _CPU_USAGE.fullmatch(name)]

    gpu_joules = 0.0
    saw_power = False
    for row in rows:
        delta_s = _float(row.get("Delta"))
        if delta_s is None:
            continue
        delta_s /= 1000.0
        for column in power_cols:
            power_mw = _float(row.get(column))
            if power_mw is None:
                continue
            saw_power = True
            gpu_joules += power_mw * delta_s / 1000.0

    cpu_joules = None
    if "CPU_ENERGY (J)" in fieldnames:
        start = _float(rows[0].get("CPU_ENERGY (J)"))
        end = _float(rows[-1].get("CPU_ENERGY (J)"))
        if start is not None and end is not None:
            cpu_joules = end - start

    system_cols = ["USED_MEMORY"] if "USED_MEMORY" in fieldnames else []
    return {
        "samples": len(rows),
        "total_gpu_joules": gpu_joules if saw_power else None,
        "total_cpu_joules": cpu_joules,
        "mean_gpu_utilization_pct": _mean_devices(rows, gpu_usage_cols),
        "mean_cpu_utilization_pct": _mean_devices(rows, cpu_usage_cols),
        "peak_gpu_memory_mib": _peak(rows, gpu_memory_cols),
        "peak_system_memory_bytes": _peak(rows, system_cols),
    }


def _mean_devices(rows, columns) -> float | None:
    if not columns:
        return None
    sample_means = []
    for row in rows:
        values = [value for column in columns if (value := _float(row.get(column))) is not None]
        if values:
            sample_means.append(sum(values) / len(values))
    if not sample_means:
        return None
    return sum(sample_means) / len(sample_means)


def _peak(rows, columns) -> float | None:
    values = [
        value
        for row in rows
        for column in columns
        if (value := _float(row.get(column))) is not None
    ]
    return max(values) if values else None


def _float(text):
    if text is None or text == "":
        return None
    try:
        return float(text)
    except ValueError:
        return None
