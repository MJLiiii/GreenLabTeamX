"""
Single source of truth for the experiment settings (see ExperimentPlanning.md).

Everything that can change the answers or the measured energy lives here, so
it is written to every run.json and cannot drift silently between runs.
"""

import hashlib
import json
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"
RESULTS_DIR = ROOT / "results"
ARTIFACTS_DIR = ROOT / "artifacts"
MF_ARTIFACT = ARTIFACTS_DIR / "mf_router.npz"  # legacy pooled file, if one was fitted
CALIBRATION_FILE = ARTIFACTS_DIR / "router_calibration.json"
EMBEDDING_CACHE_DIR = ARTIFACTS_DIR / "embeddings"

# The measured experiment. Each benchmark is scored and fitted on its own.
EXPERIMENT_BENCHMARKS = ["mmlu_pro", "gsm_hard"]


def mf_artifact(benchmark: str) -> Path:
    """Weights for one benchmark. MMLU-Pro and GSM-Hard are never fitted together."""
    return ARTIFACTS_DIR / f"mf_{benchmark}.npz"

# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

MODELS = {
    "small": "qwen3.5:4b",
    "middle": "qwen3.5:9b",
    "large": "qwen3.5:27b",
}
# Ordered from smallest to largest, so routers can rely on
# models[0] being the cheapest model and models[-1] the strongest one.
MODEL_ORDER = [MODELS["small"], MODELS["middle"], MODELS["large"]]

# Used by the matrix-factorization router to embed queries.
# The qwen3.5 models cannot produce embeddings. Pull it with:
#   ollama pull nomic-embed-text:v1.5
EMBEDDING_MODEL = "nomic-embed-text:v1.5"

# ---------------------------------------------------------------------------
# Ollama and generation settings
# ---------------------------------------------------------------------------

OLLAMA_URL = "http://localhost:11434"
CLIENT_TIMEOUT_S = 600
NUM_CTX = 4096

# Applied to every generate call of every strategy. Logprobs are requested
# everywhere (not only by the cascade) so the overhead is the same for all.
GENERATION = {
    "keep_alive": -1,
    "num_ctx": NUM_CTX,
    "think": False,
    "logprobs": True,
    "options": {"temperature": 0, "seed": 42},
}

# Sent as num_predict. Answers cut off at this limit are flagged as truncated.
MAX_NEW_TOKENS = {
    "mmlu_pro": 1024,
    "gsm_hard": 768,
}

# ---------------------------------------------------------------------------
# Benchmarks
# ---------------------------------------------------------------------------

DATASETS = {
    "mmlu_pro": {"hf_id": "TIGER-Lab/MMLU-Pro", "split": "test"},
    "gsm_hard": {"hf_id": "reasoning-machines/gsm-hard", "split": "train"},
}

# Disjoint question sets. "train" is the calibration/training split: it is the
# only split used to collect labels, fit MF, and choose thresholds. "eval" is
# held out. "calibration" is accepted as a name for the train file.
SAMPLE_SIZES = {
    "mmlu_pro": {"train": 600, "eval": 200},
    "gsm_hard": {"train": 600, "eval": 200},
}
SEED = 42

# Prompts that would leave less than MAX_NEW_TOKENS + margin of the context
# window are dropped by scripts/prepare_data.py. Tokens are estimated as
# characters / CHARS_PER_TOKEN.
CHARS_PER_TOKEN = 4
CONTEXT_MARGIN_TOKENS = 256

# ---------------------------------------------------------------------------
# Experiment protocol
# ---------------------------------------------------------------------------

EXPERIMENT = {
    "repetitions": 5,
    "cooldown_s": 60,   # sleep before every run
    "idle_s": 60,       # length of each idle-baseline run
    "warmup_s": 120,    # total warm-up time, split across the models
}

ENERGIBRIDGE = {
    "path": "energibridge",
    # Passed as -i. EnergiBridge 0.0.7's help says microseconds, but the value
    # is milliseconds (measured). Below 200 ms it warns that CPU usage is inaccurate.
    "interval_ms": 200,
    "max_seconds": 6 * 60 * 60,   # safety stop for a single run
}

# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------

MF = {
    "rank": 16,
    "l2": 1e-3,
    "lr": 0.05,
    "epochs": 2000,
    "val_fraction": 0.2,
}

# Both routers get the cheapest threshold whose simulated accuracy on the
# train split is at least this fraction of always-large's accuracy.
CALIBRATION_QUALITY_TARGET = 0.95
THRESHOLD_GRID = [round(i * 0.02, 2) for i in range(51)]


def settings_fingerprint() -> str:
    """Hash of everything that changes the model answers.

    Router training labels are only valid for the settings they were
    collected with, so the MF artifact stores this and runs compare it.
    """
    from benchmarks import BENCHMARKS  # imported here: benchmarks imports config

    payload = {
        "models": MODEL_ORDER,
        "generation": GENERATION,
        "max_new_tokens": MAX_NEW_TOKENS,
        "prompts": {
            name: benchmark.prompt_template
            for name, benchmark in sorted(BENCHMARKS.items())
        },
    }
    encoded = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:16]
