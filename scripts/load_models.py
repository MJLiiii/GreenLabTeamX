"""
Load all experiment models into Ollama and keep them loaded.

Models are loaded one at a time, largest first, so they are placed on the
GPUs the same way every time (see experiment/models.py).

    python -m scripts.load_models
"""

import sys

import config
from experiment.models import check_resident, gpu_snapshot, load_all
from ollama_client import OllamaClient, OllamaError


def main():
    client = OllamaClient(base_url=config.OLLAMA_URL, timeout=config.CLIENT_TIMEOUT_S)
    try:
        load_all(client)
    except OllamaError as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        return 1

    problems = check_resident(client)
    for problem in problems:
        print(f"[WARNING] {problem}")

    print("\nGPU placement:")
    snapshot = gpu_snapshot()
    for gpu in snapshot.get("gpus", []):
        print(f"  GPU{gpu['index']}: {gpu['memory_used_mib']:.0f} MiB used")
    for process in snapshot.get("processes", []):
        print(
            f"    GPU{process['gpu']} pid {process['pid']}: "
            f"{process['used_memory_mib']:.0f} MiB ({process['name']})"
        )

    print("\nDone. Check with: ollama ps")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
