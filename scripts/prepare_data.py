"""
Download MMLU-Pro and GSM-Hard once and freeze the question sets.

Writes data/<benchmark>_{train,eval}.jsonl and data/manifest.json. Measured
runs only read these files, so they never touch the network and every team
member runs exactly the same questions.

    python -m scripts.prepare_data
    python -m scripts.prepare_data --benchmarks gsm_hard
"""

import argparse
import json
import random
from collections import defaultdict
from datetime import datetime, timezone

import config
from benchmarks import BENCHMARKS
from benchmarks.base import sha256_file, write_questions

MANIFEST_PATH = config.DATA_DIR / "manifest.json"


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument(
        "--benchmarks", nargs="+", default=sorted(BENCHMARKS), choices=sorted(BENCHMARKS),
    )
    return parser.parse_args()


def main():
    args = parse_args()
    config.DATA_DIR.mkdir(parents=True, exist_ok=True)

    manifest = {"benchmarks": {}}
    if MANIFEST_PATH.exists():
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    for name in args.benchmarks:
        manifest["benchmarks"][name] = prepare(BENCHMARKS[name])

    manifest["seed"] = config.SEED
    manifest["updated_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Manifest: {MANIFEST_PATH}")


def prepare(benchmark) -> dict:
    # Imported here so the rest of the project does not need these packages.
    from datasets import load_dataset
    from huggingface_hub import HfApi

    source = config.DATASETS[benchmark.name]
    revision = HfApi().dataset_info(source["hf_id"]).sha
    dataset = load_dataset(source["hf_id"], split=source["split"], revision=revision)

    questions = [benchmark.from_hf_row(row, index) for index, row in enumerate(dataset)]
    unique = _drop_duplicates(questions)
    fitting = [q for q in unique if _fits_context(benchmark, q)]

    sizes = config.SAMPLE_SIZES[benchmark.name]
    splits = _split(fitting, sizes["train"], sizes["eval"], config.SEED)

    entry = {
        "hf_id": source["hf_id"],
        "hf_split": source["split"],
        "revision": revision,
        "n_source": len(questions),
        "n_duplicates_dropped": len(questions) - len(unique),
        "n_too_long_dropped": len(unique) - len(fitting),
        "splits": {},
    }
    for split, split_questions in splits.items():
        path = benchmark.data_path(split)
        write_questions(path, split_questions)
        entry["splits"][split] = {
            "file": str(path.relative_to(config.ROOT)),
            "n": len(split_questions),
            "sha256": sha256_file(path),
        }
        print(f"{benchmark.name:<9} {split:<5} {len(split_questions):>5} -> {path}")

    return entry


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _drop_duplicates(questions):
    """Keep the first question for each question text.

    Duplicates would otherwise end up in both train and eval.
    """
    seen = set()
    unique = []
    for question in questions:
        key = " ".join(question.text.split()).lower()
        if key not in seen:
            seen.add(key)
            unique.append(question)
    return unique


def _fits_context(benchmark, question) -> bool:
    """True if the prompt leaves room for the maximum answer length."""
    prompt_tokens = len(benchmark.format_prompt(question)) / config.CHARS_PER_TOKEN
    needed = (
        prompt_tokens
        + config.MAX_NEW_TOKENS[benchmark.name]
        + config.CONTEXT_MARGIN_TOKENS
    )
    return needed <= config.NUM_CTX


def _split(questions, n_train, n_eval, seed):
    """Seeded, disjoint train/eval samples, stratified by category."""
    if n_train + n_eval > len(questions):
        raise ValueError(
            f"Asked for {n_train} train + {n_eval} eval questions, "
            f"but only {len(questions)} are available."
        )

    rng = random.Random(seed)
    groups = defaultdict(list)
    for question in questions:
        groups[question.category or ""].append(question)
    for category in sorted(groups):
        rng.shuffle(groups[category])

    splits = {}
    for split, n in (("eval", n_eval), ("train", n_train)):
        quotas = _proportional({c: len(g) for c, g in groups.items()}, n)
        taken = []
        for category in sorted(groups):
            taken += groups[category][: quotas[category]]
            groups[category] = groups[category][quotas[category]:]
        # Interleave categories; this order is then fixed for every run.
        rng.shuffle(taken)
        splits[split] = taken

    return {"train": splits["train"], "eval": splits["eval"]}


def _proportional(counts: dict, total: int) -> dict:
    """Split total over the keys in proportion to counts (largest remainder)."""
    available = sum(counts.values())
    exact = {key: total * count / available for key, count in counts.items()}
    quotas = {key: int(value) for key, value in exact.items()}
    leftover = total - sum(quotas.values())
    by_remainder = sorted(counts, key=lambda key: (quotas[key] - exact[key], key))
    for key in by_remainder[:leftover]:
        quotas[key] += 1
    return quotas


if __name__ == "__main__":
    main()
