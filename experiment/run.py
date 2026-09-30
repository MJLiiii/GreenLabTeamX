"""
One run: one router answers one benchmark split, and everything is recorded.

    python -m experiment.run --router always_small --benchmark gsm_hard \
        --split eval --out-dir results/pilot/always_small__gsm_hard

Writes into --out-dir:

    queries.csv  one row per question (final answer, correctness, totals)
    calls.csv    one row per Ollama call (generate or embed), with Unix-ms
                 timestamps that line up with EnergiBridge's Time column
    run.json     everything needed to reproduce the run

Energy is measured from the outside: experiment/run_experiment.py wraps this
command with EnergiBridge.
"""

import argparse
import csv
import json
import platform
import socket
import sys
import time
from collections import Counter
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

import config
from benchmarks import BENCHMARKS
from benchmarks.base import load_questions, sha256_file
from experiment.session import CallRecord, QuerySession
from ollama_client import OllamaClient, OllamaError
from routers import ROUTERS, build_router

QUERY_FIELDS = [
    "run_id",
    "query_id",
    "benchmark",
    "split",
    "category",
    "router",
    "final_model",
    "models_called",
    "num_generate_calls",
    "extracted_answer",
    "reference",
    "correct",
    "extraction_failed",
    "truncated",
    "started_at_ms",
    "ended_at_ms",
    "latency_s",
    "latency_ms",
    "routing_latency_s",
    "prompt_tokens_total",
    "completion_tokens_total",
    "error",
]

CALL_FIELDS = [
    "run_id",
    "query_id",
    "call_index",
    "kind",
    "model",
    "started_at_ms",
    "ended_at_ms",
    "latency_s",
    "total_duration_s",
    "load_duration_s",
    "prompt_eval_duration_s",
    "eval_duration_s",
    "prompt_tokens",
    "prompt_cached_tokens",
    "completion_tokens",
    "done_reason",
    "response",
    "extracted_answer",
    "confidence",
    "seq_confidence",
    "correct",
    "is_final",
    "error",
]

# A call that spends longer than this loading its model means the model was
# unloaded during the run, which distorts both latency and energy.
RELOAD_WARNING_S = 1.0


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Answer one benchmark split with one router and record every call."
    )
    parser.add_argument("--router", required=True, choices=sorted(ROUTERS))
    parser.add_argument("--benchmark", required=True, choices=sorted(BENCHMARKS))
    parser.add_argument("--split", choices=["calibration", "train", "eval"], default="eval")
    parser.add_argument(
        "--limit", type=int, default=None, help="only run the first N questions",
    )
    parser.add_argument(
        "--data", type=Path, default=None,
        help="question file to use instead of data/<benchmark>_<split>.jsonl",
    )
    parser.add_argument(
        "--out-dir", type=Path, default=None,
        help="default: results/adhoc/<router>__<benchmark>__<split>",
    )
    parser.add_argument("--run-id", default=None, help="default: name of --out-dir")
    parser.add_argument(
        "--threshold", type=float, default=None,
        help="cascade/mf threshold (default: artifacts/router_calibration.json)",
    )
    parser.add_argument("--ollama-url", default=config.OLLAMA_URL)
    return parser.parse_args(argv)


def run_query(client, router, benchmark, question, run_id, split):
    """Let the router answer one question and return (query row, call records)."""
    session = QuerySession(client, benchmark, question)

    started_at_ms = _now_ms()
    start = time.perf_counter()
    final = None
    error = None
    try:
        final = router.run(question, session)
    except OllamaError as e:
        # Keep going so one failed query does not lose the rest of the run.
        error = str(e)
    latency_s = time.perf_counter() - start
    ended_at_ms = _now_ms()

    # Score every generate call, including rejected cascade stages.
    for call in session.calls:
        if call.kind == "generate" and call.error is None:
            call.correct = benchmark.is_correct(call.extraction, question)
        call.is_final = final is not None and call.call_index == final.call_index

    generate_calls = [c for c in session.calls if c.kind == "generate"]
    final_call = next((c for c in session.calls if c.is_final), None)
    if final is not None and final.error:
        error = final.error

    row = {
        "run_id": run_id,
        "query_id": question.id,
        "benchmark": benchmark.name,
        "split": split,
        "category": question.category,
        "router": router.name,
        "final_model": final.model if final else None,
        "models_called": ">".join(c.model for c in generate_calls),
        "num_generate_calls": len(generate_calls),
        "extracted_answer": final_call.extracted_answer if final_call else None,
        "reference": question.reference,
        "correct": final_call.correct if final_call else None,
        "extraction_failed": (
            final_call is not None and final_call.error is None
            and final_call.extraction is None
        ),
        "truncated": final_call is not None and final_call.done_reason == "length",
        "started_at_ms": started_at_ms,
        "ended_at_ms": ended_at_ms,
        "latency_s": latency_s,
        "latency_ms": latency_s * 1000.0,
        # Time before the final generate call (embedding, rejected cascade
        # stages, router work). latency_ms is the end-to-end figure.
        "routing_latency_s": latency_s - (final_call.latency_s if final_call else 0.0),
        "prompt_tokens_total": sum(c.prompt_tokens or 0 for c in generate_calls),
        "completion_tokens_total": sum(c.completion_tokens or 0 for c in generate_calls),
        "error": error,
    }
    return row, session.calls


def main(argv=None):
    args = parse_args(argv)

    benchmark = BENCHMARKS[args.benchmark]
    try:
        router = build_router(args.router, args.threshold, benchmark=args.benchmark)
    except (FileNotFoundError, ValueError) as e:
        print(f"Cannot build router {args.router!r}: {e}", file=sys.stderr)
        return 2

    data_path = args.data or benchmark.data_path(args.split)
    questions = load_questions(data_path)[: args.limit]

    out_dir = args.out_dir or (
        config.RESULTS_DIR / "adhoc" / f"{args.router}__{args.benchmark}__{args.split}"
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    run_id = args.run_id or out_dir.name

    client = OllamaClient(base_url=args.ollama_url, timeout=config.CLIENT_TIMEOUT_S)
    if not client.is_available():
        print(f"Ollama is not reachable at {client.base_url}", file=sys.stderr)
        return 1

    run_info = {
        "run_id": run_id,
        "started_at": _now_iso(),
        "finished_at": None,
        "router": router.config(),
        "benchmark": benchmark.name,
        "split": args.split,
        "data_file": str(data_path),
        "data_sha256": sha256_file(data_path),
        "num_questions": len(questions),
        "settings_fingerprint": config.settings_fingerprint(),
        "generation": config.GENERATION,
        "max_new_tokens": config.MAX_NEW_TOKENS[benchmark.name],
        "embedding_model": config.EMBEDDING_MODEL,
        "ollama_url": client.base_url,
        "client_timeout_s": client.timeout,
        "python_version": platform.python_version(),
        "hostname": socket.gethostname(),
    }
    _write_json(out_dir / "run.json", run_info)

    print(
        f"Router: {router.name} | benchmark: {benchmark.name}/{args.split} | "
        f"questions: {len(questions)} | output: {out_dir}"
    )

    rows = []
    all_calls = []
    run_start = time.perf_counter()

    with open(out_dir / "queries.csv", "w", newline="", encoding="utf-8") as qf, \
         open(out_dir / "calls.csv", "w", newline="", encoding="utf-8") as cf:
        query_writer = csv.DictWriter(qf, fieldnames=QUERY_FIELDS)
        call_writer = csv.DictWriter(cf, fieldnames=CALL_FIELDS)
        query_writer.writeheader()
        call_writer.writeheader()

        for question in questions:
            row, calls = run_query(client, router, benchmark, question, run_id, args.split)

            query_writer.writerow(row)
            for call in calls:
                call_writer.writerow(_call_row(call, run_id, question.id))
            # Flush every question so partial results survive a crash or Ctrl+C.
            qf.flush()
            cf.flush()

            rows.append(row)
            all_calls.extend(calls)
            _print_row(row)

    total_seconds = time.perf_counter() - run_start
    summary = _summary(rows, all_calls, total_seconds)

    run_info["finished_at"] = _now_iso()
    run_info["summary"] = summary
    _write_json(out_dir / "run.json", run_info)

    _print_summary(summary)
    return 1 if summary["errors"] else 0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _call_row(call: CallRecord, run_id, query_id) -> dict:
    row = {k: v for k, v in asdict(call).items() if k in CALL_FIELDS}
    return {**row, "run_id": run_id, "query_id": query_id}


def _summary(rows, calls, total_seconds) -> dict:
    n = len(rows)
    answered = [r for r in rows if not r["error"]]
    reloads = [
        c for c in calls
        if c.load_duration_s is not None and c.load_duration_s > RELOAD_WARNING_S
    ]
    return {
        "questions": n,
        "errors": n - len(answered),
        "accuracy": sum(bool(r["correct"]) for r in rows) / n if n else None,
        "extraction_failed": sum(r["extraction_failed"] for r in rows),
        "truncated": sum(r["truncated"] for r in rows),
        "final_models": dict(Counter(r["final_model"] for r in answered)),
        "generate_calls": sum(r["num_generate_calls"] for r in rows),
        "model_reloads": len(reloads),
        "total_seconds": total_seconds,
        "mean_latency_s": sum(r["latency_s"] for r in rows) / n if n else None,
        "mean_latency_ms": sum(r["latency_ms"] for r in rows) / n if n else None,
    }


def _now_ms() -> int:
    return time.time_ns() // 1_000_000


def _now_iso():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _write_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def _print_row(row):
    if row["error"]:
        outcome = f"ERROR: {row['error']}"
    else:
        mark = "ok " if row["correct"] else "no "
        outcome = f"{mark} answer={row['extracted_answer']} ref={row['reference']}"
    print(
        f"[{row['query_id']:>6}] {row['models_called']:<36} "
        f"{row['latency_s']:6.2f}s  {outcome}"
    )


def _print_summary(summary):
    n = summary["questions"]
    print("\nFinal model distribution:")
    for model, count in sorted(summary["final_models"].items()):
        print(f"  {model:<12} {count:>4}  ({count / n:.0%})")

    accuracy = summary["accuracy"]
    print(f"\nAccuracy:          {accuracy:.1%}" if accuracy is not None else "")
    print(f"Extraction failed: {summary['extraction_failed']}")
    print(f"Truncated:         {summary['truncated']}")
    print(f"Generate calls:    {summary['generate_calls']}")
    print(f"Total time:        {summary['total_seconds']:.2f}s")
    if summary["mean_latency_s"] is not None:
        print(f"Mean latency:      {summary['mean_latency_s']:.2f}s")
        print(f"Mean latency:      {summary['mean_latency_ms']:.0f} ms/query")
    print(f"Errors:            {summary['errors']}")
    if summary["model_reloads"]:
        print(
            f"WARNING: {summary['model_reloads']} call(s) reloaded a model; "
            f"latency and energy of this run are affected."
        )


if __name__ == "__main__":
    sys.exit(main())
