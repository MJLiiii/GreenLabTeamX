"""
Run the experiment: every router × benchmark × repetition, measured with EnergiBridge.

    python -m experiment.run_experiment --dry-run
    python -m experiment.run_experiment --exp-id main
    python -m experiment.run_experiment --exp-id main --resume

Collect calibration labels for scripts/fit_routers.py (no energy measurement):

    python -m experiment.run_experiment --exp-id calibration --split train \
        --routers small_only medium_only large_only --reps 1 --no-energy

Protocol:
  1. make sure all models are loaded (fixed order, see experiment/models.py)
  2. warm every model up on train questions (never on eval questions)
  3. shuffle all runs, plus one idle run per repetition, with a fixed seed,
     and write the plan to results/<exp_id>/manifest.csv before starting
  4. per run: cooldown, GPU snapshot, residency check, run, residency check

Each run gets its own folder with queries.csv, calls.csv, run.json,
energy.csv (EnergiBridge) and stdout.log. The manifest is rewritten after
every run, so --resume can continue an interrupted experiment.
"""

import argparse
import csv
import json
import random
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import config
from benchmarks import BENCHMARKS
from benchmarks.base import load_questions
from experiment.models import check_resident, gpu_snapshot, load_all
from experiment.session import QuerySession
from measurement.aggregate import summarize_run
from measurement.energibridge import summary_joules, wrap
from measurement.hardware import collect_hardware
from ollama_client import OllamaClient
from routers import CANONICAL_STRATEGIES, ROUTERS, build_router

MANIFEST_FIELDS = [
    "run_id",
    "order_index",
    "kind",
    "router",
    "benchmark",
    "split",
    "repetition",
    "status",
    "exit_code",
    "started_at_ms",
    "ended_at_ms",
    "duration_s",
    "eb_summary_joules",
    "gpu_temps_start",
    "gpu_placement",
    "resident_ok_before",
    "resident_ok_after",
    "n_queries",
    "n_errors",
    "accuracy",
    "mean_latency_ms",
    "mean_j_per_query",
    "mean_gpu_utilization_pct",
    "mean_cpu_utilization_pct",
    "peak_gpu_memory_mib",
    "peak_system_memory_bytes",
    "run_dir",
]

# Statuses that --resume does not run again. "errors" means the run finished
# but some queries failed; those failures are recorded per query.
FINISHED = {"done", "errors"}


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Run every strategy × benchmark × repetition, wrapped in EnergiBridge."
    )
    parser.add_argument(
        "--routers", nargs="+", default=list(CANONICAL_STRATEGIES), choices=sorted(ROUTERS),
    )
    parser.add_argument(
        "--benchmarks", nargs="+",
        default=list(config.EXPERIMENT_BENCHMARKS), choices=sorted(BENCHMARKS),
    )
    parser.add_argument("--split", choices=["calibration", "train", "eval"], default="eval")
    parser.add_argument("--reps", type=int, default=config.EXPERIMENT["repetitions"])
    parser.add_argument("--limit", type=int, default=None, help="questions per run")
    parser.add_argument("--exp-id", default=None, help="default: <split>_<timestamp>")
    parser.add_argument("--seed", type=int, default=config.SEED, help="run order seed")
    parser.add_argument(
        "--no-energy", action="store_true",
        help="run without EnergiBridge and without idle runs (e.g. train labels)",
    )
    parser.add_argument(
        "--cooldown-s", type=float, default=None,
        help=f"default: {config.EXPERIMENT['cooldown_s']}, or 0 with --no-energy",
    )
    parser.add_argument(
        "--warmup-s", type=float, default=None,
        help=f"default: {config.EXPERIMENT['warmup_s']}, or 0 with --no-energy",
    )
    parser.add_argument("--idle-s", type=float, default=config.EXPERIMENT["idle_s"])
    parser.add_argument("--cascade-threshold", type=float, default=None)
    parser.add_argument("--mf-threshold", type=float, default=None)
    parser.add_argument("--dry-run", action="store_true", help="print the plan and exit")
    parser.add_argument(
        "--resume", action="store_true",
        help="continue results/<exp-id> with its saved plan and settings",
    )
    return parser.parse_args(argv)


def build_plan(routers, benchmarks, split, reps, idle, seed) -> list[dict]:
    """All runs of the experiment in a seeded random order."""
    runs = []
    for repetition in range(1, reps + 1):
        for router in routers:
            for benchmark in benchmarks:
                runs.append({
                    "kind": "run", "router": router, "benchmark": benchmark,
                    "split": split, "repetition": repetition,
                })
        if idle:
            runs.append({
                "kind": "idle", "router": "", "benchmark": "",
                "split": "", "repetition": repetition,
            })

    random.Random(seed).shuffle(runs)

    for order_index, run in enumerate(runs, start=1):
        if run["kind"] == "idle":
            name = f"idle__rep{run['repetition']}"
        else:
            name = f"{run['router']}__{run['benchmark']}__rep{run['repetition']}"
        run.update(
            run_id=f"{order_index:03d}_{name}",
            order_index=order_index,
            status="planned",
        )
    return runs


def main(argv=None):
    args = parse_args(argv)
    exp_id = args.exp_id or f"{args.split}_{datetime.now():%Y%m%d_%H%M%S}"
    exp_dir = config.RESULTS_DIR / exp_id

    if args.resume:
        if not args.exp_id:
            print("--resume needs --exp-id", file=sys.stderr)
            return 2
        settings, runs = _load_experiment(exp_dir)
    else:
        if (exp_dir / "manifest.csv").exists() and not args.dry_run:
            print(f"{exp_dir} already exists; use --resume or another --exp-id", file=sys.stderr)
            return 2
        settings = _settings_from_args(args, exp_id)
        runs = build_plan(
            args.routers, args.benchmarks, args.split, args.reps,
            idle=settings["energy"], seed=args.seed,
        )

    if args.dry_run:
        _print_plan(runs, settings)
        return 0

    client = OllamaClient(base_url=config.OLLAMA_URL, timeout=config.CLIENT_TIMEOUT_S)
    if not client.is_available():
        print(f"Ollama is not reachable at {client.base_url}", file=sys.stderr)
        return 1

    # Fail now rather than hours into the experiment (e.g. no MF artifact).
    pairs = sorted({
        (run["router"], run["benchmark"])
        for run in runs if run["kind"] == "run"
    })
    for name, benchmark in pairs:
        try:
            build_router(name, _threshold(settings, name), benchmark=benchmark)
        except (FileNotFoundError, ValueError, KeyError) as e:
            print(f"Cannot build router {name!r} for {benchmark}: {e}", file=sys.stderr)
            return 2

    exp_dir.mkdir(parents=True, exist_ok=True)
    if not args.resume:
        settings["hardware"] = collect_hardware()
        _write_json(exp_dir / "experiment.json", settings)
    _write_manifest(exp_dir, runs)

    if not _ensure_resident(client):
        print("Models are not loaded correctly; aborting.", file=sys.stderr)
        return 1

    benchmarks = sorted({run["benchmark"] for run in runs if run["kind"] == "run"})
    warm_up(client, settings["warmup_s"], [BENCHMARKS[name] for name in benchmarks])

    pending = [run for run in runs if run["status"] not in FINISHED]
    print(f"\nExperiment {exp_id}: {len(pending)} of {len(runs)} runs to go -> {exp_dir}\n")

    for number, run in enumerate(pending, start=1):
        print(f"[{number}/{len(pending)}] {run['run_id']}")
        try:
            execute(run, exp_dir, settings, client)
        except KeyboardInterrupt:
            run["status"] = "interrupted"
            _write_manifest(exp_dir, runs)
            print(f"\nInterrupted. Continue with: --exp-id {exp_id} --resume")
            return 130
        _write_manifest(exp_dir, runs)
        print(f"    -> {run['status']} ({float(run['duration_s']):.0f}s)")

    statuses = [run["status"] for run in runs]
    print(f"\nDone: {statuses.count('done')} done, {len(runs) - statuses.count('done')} other.")
    print(f"Manifest: {exp_dir / 'manifest.csv'}")
    return 0 if all(status in FINISHED for status in statuses) else 1


def execute(run, exp_dir, settings, client):
    """Run one planned run and fill in its manifest fields."""
    run_dir = exp_dir / run["run_id"]
    run_dir.mkdir(parents=True, exist_ok=True)
    run["run_dir"] = str(run_dir.relative_to(config.ROOT))

    time.sleep(settings["cooldown_s"])

    snapshot = gpu_snapshot()
    _write_json(run_dir / "gpu_before.json", snapshot)
    run["gpu_temps_start"] = ";".join(
        f"{gpu['temperature_c']:.0f}" for gpu in snapshot.get("gpus", [])
    )
    run["gpu_placement"] = ";".join(
        f"gpu{p['gpu']}:{p['used_memory_mib']:.0f}MiB"
        for p in snapshot.get("processes", [])
    )
    run["resident_ok_before"] = _ensure_resident(client)

    command = _command(run, run_dir, settings)
    run["started_at_ms"] = _now_ms()
    with open(run_dir / "stdout.log", "w", encoding="utf-8") as log:
        completed = subprocess.run(
            command, cwd=config.ROOT, stdout=log, stderr=subprocess.STDOUT,
        )
    run["ended_at_ms"] = _now_ms()
    run["duration_s"] = (run["ended_at_ms"] - run["started_at_ms"]) / 1000
    run["exit_code"] = completed.returncode

    problems = check_resident(client)
    run["resident_ok_after"] = not problems
    run["eb_summary_joules"] = _summary_joules(run_dir / "stdout.log")

    if run["kind"] == "idle":
        run["status"] = "done" if completed.returncode == 0 else "failed"
    else:
        run["n_queries"], run["n_errors"] = _count_queries(run_dir / "queries.csv")
        run["status"] = _run_status(run_dir, completed.returncode)

    if problems:
        # A model was unloaded during the run: its energy and latency are
        # not comparable. Reload so the next run starts clean.
        run["status"] = "invalid"
        for problem in problems:
            print(f"    WARNING: {problem}")
        _ensure_resident(client)

    metrics = summarize_run(run_dir, hardware=settings.get("hardware"))
    for field in (
        "accuracy", "mean_latency_ms", "mean_j_per_query",
        "mean_gpu_utilization_pct", "mean_cpu_utilization_pct",
        "peak_gpu_memory_mib", "peak_system_memory_bytes",
    ):
        if metrics.get(field) is not None:
            run[field] = metrics[field]


def warm_up(client, seconds, benchmarks, log=print):
    """Generate with every model for a while, on calibration questions only."""
    if seconds <= 0 or not benchmarks:
        return

    loaded = []
    for benchmark in benchmarks:
        questions = _warmup_questions(benchmark)
        if questions:
            loaded.append((benchmark, questions))
    if not loaded:
        log("Warm-up skipped: no calibration questions on disk.")
        return

    pool = [
        (benchmark, question)
        for bundle in zip(*(questions for _, questions in loaded))
        for benchmark, question in zip((item[0] for item in loaded), bundle)
    ]

    log(f"Warming up for {seconds:.0f}s ...")
    per_model = seconds / len(config.MODEL_ORDER)
    position = 0
    for model in config.MODEL_ORDER:
        deadline = time.monotonic() + per_model
        count = 0
        while count == 0 or time.monotonic() < deadline:
            benchmark, question = pool[position % len(pool)]
            position += 1
            QuerySession(client, benchmark, question).generate(model)
            count += 1
        log(f"  {model}: {count} prompt(s)")

    benchmark, question = pool[0]
    QuerySession(client, benchmark, question).embed(question.text)


def _warmup_questions(benchmark, limit=20):
    """Calibration/train questions only. Eval is never used for warm-up."""
    for split in ("calibration", "train"):
        path = benchmark.data_path(split)
        if path.exists() and split != "eval":
            return benchmark.load(split, limit=limit)
    return []


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _settings_from_args(args, exp_id) -> dict:
    energy = not args.no_energy
    return {
        "exp_id": exp_id,
        "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "routers": args.routers,
        "benchmarks": args.benchmarks,
        "split": args.split,
        "reps": args.reps,
        "limit": args.limit,
        "seed": args.seed,
        "energy": energy,
        "cooldown_s": _default(args.cooldown_s, config.EXPERIMENT["cooldown_s"], energy),
        "warmup_s": _default(args.warmup_s, config.EXPERIMENT["warmup_s"], energy),
        "idle_s": args.idle_s,
        "thresholds": {"cascade": args.cascade_threshold, "mf": args.mf_threshold},
        "energibridge": config.ENERGIBRIDGE,
        "settings_fingerprint": config.settings_fingerprint(),
    }


def _default(value, configured, energy):
    if value is not None:
        return value
    return configured if energy else 0


def _threshold(settings, router):
    return settings["thresholds"].get(router)


def _command(run, run_dir, settings) -> list[str]:
    if run["kind"] == "idle":
        command = ["sleep", str(settings["idle_s"])]
    else:
        command = [
            sys.executable, "-m", "experiment.run",
            "--router", run["router"],
            "--benchmark", run["benchmark"],
            "--split", run["split"],
            "--out-dir", str(run_dir),
            "--run-id", run["run_id"],
        ]
        if settings["limit"] is not None:
            command += ["--limit", str(settings["limit"])]
        threshold = _threshold(settings, run["router"])
        if threshold is not None:
            command += ["--threshold", str(threshold)]

    if not settings["energy"]:
        return command
    return wrap(command, run_dir / "energy.csv")


def _ensure_resident(client) -> bool:
    """Check the models are loaded; reload them once if not."""
    problems = check_resident(client)
    if not problems:
        return True
    for problem in problems:
        print(f"    {problem}")
    print("    Reloading models ...")
    load_all(client, log=lambda message: print(f"    {message}"))
    problems = check_resident(client)
    for problem in problems:
        print(f"    still: {problem}")
    return not problems


def _run_status(run_dir, exit_code) -> str:
    run_json = run_dir / "run.json"
    if not run_json.exists():
        return "failed"
    finished = json.loads(run_json.read_text(encoding="utf-8")).get("finished_at")
    if finished is None:
        # Killed (e.g. EnergiBridge --max-execution) before it could finish.
        return "failed"
    return "done" if exit_code == 0 else "errors"


def _count_queries(path):
    if not path.exists():
        return 0, 0
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    return len(rows), sum(1 for row in rows if row["error"])


def _summary_joules(log_path):
    if not log_path.exists():
        return None
    return summary_joules(log_path.read_text(encoding="utf-8"))


def _load_experiment(exp_dir: Path):
    settings = json.loads((exp_dir / "experiment.json").read_text(encoding="utf-8"))
    if settings["settings_fingerprint"] != config.settings_fingerprint():
        raise SystemExit(
            f"{exp_dir} was started with other prompts or generation settings; "
            f"start a new experiment instead of resuming."
        )
    with open(exp_dir / "manifest.csv", newline="", encoding="utf-8") as f:
        runs = list(csv.DictReader(f))
    return settings, runs


def _write_manifest(exp_dir, runs):
    path = exp_dir / "manifest.csv"
    temporary = path.with_suffix(".csv.tmp")
    with open(temporary, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=MANIFEST_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(runs)
    temporary.replace(path)


def _print_plan(runs, settings):
    for run in runs:
        print(f"  {run['run_id']:<45} {run['status']}")

    measured = [run for run in runs if run["kind"] == "run"]
    idle = len(runs) - len(measured)
    questions = 0
    for run in measured:
        path = BENCHMARKS[run["benchmark"]].data_path(run["split"])
        available = len(load_questions(path)) if path.exists() else 0
        questions += min(available, settings["limit"] or available)

    print(
        f"\n{len(runs)} runs ({len(measured)} measured, {idle} idle), "
        f"{questions} questions in total, energy={'on' if settings['energy'] else 'off'}, "
        f"cooldown={settings['cooldown_s']}s, warm-up={settings['warmup_s']}s"
    )


def _write_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def _now_ms() -> int:
    return time.time_ns() // 1_000_000


if __name__ == "__main__":
    sys.exit(main())
