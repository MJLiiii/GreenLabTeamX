"""
Keep the experiment's models loaded in a fixed, checked and recorded way.

All models (the three Qwen models and the embedding model) stay loaded
during every run, for every strategy, so idle GPU power is the same for all.

Models are loaded one at a time, largest first, so Ollama places them the
same way after every reload, and the placement is recorded per run. (Ollama
splits the 27b over both GPUs even when it is loaded alone.)
"""

import subprocess
import time

import config
from ollama_client import OllamaError

# /api/ps reports expires_at far in the future for keep_alive=-1.
# Anything earlier means someone reset the model to a finite keep_alive.
FOREVER_YEAR = 2100


def load_all(client, log=print):
    for model in reversed(config.MODEL_ORDER):
        log(f"Loading {model} (num_ctx={config.NUM_CTX}) ...")
        client.load(model, num_ctx=config.NUM_CTX, keep_alive=-1)
    log(f"Loading {config.EMBEDDING_MODEL} ...")
    client.load(config.EMBEDDING_MODEL, keep_alive=-1, embedding=True)


def unload_all(client, log=print, timeout_s=60):
    models = [(m, False) for m in config.MODEL_ORDER]
    models.append((config.EMBEDDING_MODEL, True))
    for model, embedding in models:
        log(f"Stopping {model} ...")
        try:
            client.unload(model, embedding=embedding)
        except OllamaError as e:
            log(f"  could not stop {model}: {e}")

    # Unloading is asynchronous; a reload that starts too early reuses the
    # old runners instead of placing the models again.
    names = {model for model, _ in models}
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if not names & {m["name"] for m in client.ps()}:
            return
        time.sleep(1)
    log(f"  models still loaded after {timeout_s}s")


def check_resident(client) -> list[str]:
    """Return a list of problems; an empty list means everything is loaded."""
    try:
        loaded = {m["name"]: m for m in client.ps()}
    except OllamaError as e:
        return [f"cannot list loaded models: {e}"]

    problems = []
    for model in [*config.MODEL_ORDER, config.EMBEDDING_MODEL]:
        info = loaded.get(model)
        if info is None:
            problems.append(f"{model} is not loaded")
            continue
        if model != config.EMBEDDING_MODEL and info.get("context_length") != config.NUM_CTX:
            problems.append(
                f"{model} has context_length {info.get('context_length')}, "
                f"expected {config.NUM_CTX}"
            )
        if info.get("size_vram", 0) < info.get("size", 0):
            problems.append(f"{model} is partly running on the CPU")
        expires_at = info.get("expires_at") or ""
        if expires_at[:4].isdigit() and int(expires_at[:4]) < FOREVER_YEAR:
            problems.append(f"{model} will be unloaded at {expires_at}")

    others = sorted(set(loaded) - {*config.MODEL_ORDER, config.EMBEDDING_MODEL})
    if others:
        problems.append(f"other models are loaded: {', '.join(others)}")
    return problems


def gpu_snapshot() -> dict:
    """Per-GPU temperature, memory and power, and the processes on each GPU."""
    try:
        gpus = _nvidia_smi(
            "--query-gpu=index,uuid,name,temperature.gpu,memory.used,"
            "memory.total,power.draw,utilization.gpu"
        )
        apps = _nvidia_smi("--query-compute-apps=gpu_uuid,pid,process_name,used_memory")
    except (OSError, subprocess.CalledProcessError) as e:
        return {"error": str(e)}

    index_by_uuid = {g[1]: int(g[0]) for g in gpus}
    return {
        "gpus": [
            {
                "index": int(g[0]),
                "name": g[2],
                "temperature_c": _number(g[3]),
                "memory_used_mib": _number(g[4]),
                "memory_total_mib": _number(g[5]),
                "power_w": _number(g[6]),
                "utilization_pct": _number(g[7]),
            }
            for g in gpus
        ],
        "processes": [
            {
                "gpu": index_by_uuid.get(a[0]),
                "pid": int(a[1]),
                "name": a[2],
                "used_memory_mib": _number(a[3]),
            }
            for a in apps
        ],
    }


def _nvidia_smi(query) -> list[list[str]]:
    output = subprocess.run(
        ["nvidia-smi", query, "--format=csv,noheader,nounits"],
        capture_output=True, text=True, check=True, timeout=30,
    ).stdout
    return [
        [field.strip() for field in line.split(",")]
        for line in output.splitlines() if line.strip()
    ]


def _number(text):
    try:
        return float(text)
    except ValueError:
        return None
