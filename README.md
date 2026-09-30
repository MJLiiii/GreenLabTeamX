# GreenLabTeamX: energy of LLM routing strategies

Code for the experiment in [ExperimentPlanning.md](ExperimentPlanning.md): how much energy routing strategies use, and how well they answer, compared with always using the small or the large model.

| Plan item | Where |
|---|---|
| Models: small `qwen3.5:4b`, middle `qwen3.5:9b`, big `qwen3.5:27b` | `config.py` (`MODELS`) |
| Benchmarks: MMLU-Pro, GSM-Hard | `benchmarks/`, frozen question sets in `data/` |
| Always small / middle / large | `routers/always.py` |
| Predictive: matrix factorization | `routers/matrix_factorization.py`, fitted by `scripts/fit_routers.py` |
| Non-predictive: cascade 4b → 9b → 27b | `routers/cascade.py` |
| Energy with EnergiBridge, repetitions, run order | `experiment/run_experiment.py` |

## Layout

```
config.py              every setting that affects answers or measurements
ollama_client.py       HTTP client for Ollama (generate, embed, ps, load/unload)
benchmarks/            prompts, answer extraction and scoring per benchmark
routers/               the routing strategies; they call an LLM interface, never Ollama directly
experiment/session.py  the LLM interface: fixed prompt/settings, timing, confidence, call records
experiment/run.py      one router on one benchmark split -> queries.csv, calls.csv, run.json
experiment/run_experiment.py  all runs, shuffled, wrapped in EnergiBridge
experiment/models.py   loading models in a fixed order, residency checks, GPU snapshots
measurement/           EnergiBridge adapter, GPU J/query, utilization, memory, aggregate.csv
scripts/               prepare_data, fit_routers, load_models, stop_models
data/                  frozen train/eval questions + manifest.json (dataset revision, hashes)
artifacts/             one MF router per benchmark and calibrated thresholds
results/               one folder per experiment (not committed)
tests/                 unit tests (offline) and live tests (skipped when Ollama is down)
```

## Setup

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
ollama pull qwen3.5:4b && ollama pull qwen3.5:9b && ollama pull qwen3.5:27b
ollama pull nomic-embed-text:v1.5      # used by the MF router
```

Run everything from the project root with the venv's Python (`.venv/bin/python -m ...` or activate the venv first).

## Workflow

1. **Question sets.** They are already frozen in `data/`: 600 train and 200 eval questions per benchmark, disjoint, with MMLU-Pro stratified by category. Only rerun this after changing `SAMPLE_SIZES`:
   ```bash
   python -m scripts.prepare_data
   ```
2. **Load the models.** Loads them one at a time, largest first, so they land on the same GPUs every time:
   ```bash
   python -m scripts.load_models
   ```
3. **Collect calibration labels.** Runs the three fixed-model strategies on the train split (the calibration set). Eval questions are not used. Energy measurement stays off:
   ```bash
   python -m experiment.run_experiment --exp-id calibration --split train \
       --routers small_only medium_only large_only --reps 1 --no-energy
   ```
   Older names still work: `always_small`, `always_middle`, `always_large`, `mf`.
4. **Fit one matrix-factorization router per benchmark** and calibrate cascade and MF thresholds on that benchmark's calibration split only. MMLU-Pro and GSM-Hard are fitted separately. Held-out eval labels are ignored:
   ```bash
   python -m scripts.fit_routers --results results/calibration
   ```
   This writes `artifacts/mf_mmlu_pro.npz`, `artifacts/mf_gsm_hard.npz`, `artifacts/router_calibration.json` (thresholds under `benchmarks`) and `artifacts/threshold_sweep.csv`.
5. **Run the experiment.** Five strategies (`small_only`, `medium_only`, `large_only`, `cascade`, `matrix_factorization`) on MMLU-Pro and GSM-Hard. Check the plan first, then run it; resume after an interruption with `--resume`:
   ```bash
   python -m experiment.run_experiment --dry-run
   python -m experiment.run_experiment --exp-id main
   python -m experiment.run_experiment --exp-id main --resume
   python -m measurement.aggregate results/main
   ```
   `aggregate.csv` has one row per run. MMLU-Pro accuracy and GSM-Hard accuracy are not combined. `mean_j_per_query` is total GPU joules from the EnergiBridge CSV divided by the number of evaluated queries.

A single run, for trying things out:

```bash
python -m experiment.run --router cascade --benchmark gsm_hard --limit 5 --threshold 0.9
```

## Outputs

Each experiment folder `results/<exp_id>/` contains:

| File | Contents | Research question |
|---|---|---|
| `manifest.csv` | one row per run: order, status, start/end (Unix ms), EnergiBridge summary, GPU temperatures and placement, residency checks | all |
| `<run>/energy.csv` | EnergiBridge samples every 200 ms: CPU energy counter, per-GPU power (mW), usage and memory | RQ1, RQ2, RQ3 (resource use) |
| `<run>/queries.csv` | one row per question: final model, models called, correctness, latency, tokens | RQ1.1, RQ2, RQ3 (latency) |
| `<run>/calls.csv` | one row per Ollama call, including rejected cascade stages and MF embeddings | energy per query/call, cascade analysis |
| `<run>/run.json` | router settings, thresholds, data file hash, settings fingerprint | reproducibility |
| `<run>/summary.json` | accuracy, mean latency (ms/query), mean GPU J/query, utilization, memory peaks | comparison |
| `aggregate.csv` | one scalar row per run; MMLU-Pro and GSM-Hard stay on separate rows | comparison |

The timestamps in `queries.csv` and `calls.csv` are Unix milliseconds, like EnergiBridge's `Time` column. You can therefore add up energy per query or per call, and leave out Python start-up. The `idle` runs measure the machine with all models loaded and nothing to do, so energy can be reported gross and net of idle.

## Protocol

- **Same settings for everyone.** Every strategy uses the same prompt and settings: temperature 0, seed 42, `think=false`, logprobs on, `num_ctx` 4096.
  - All four models stay loaded for every run.
  - `config.settings_fingerprint()` hashes the models, settings and prompt templates. Runs, the MF artifact and the calibration file refuse to mix different fingerprints.
- **Run order.** The order is shuffled with a fixed seed and written to the manifest before the first run.
  - One idle run is added per repetition.
  - Each run starts after a cooldown (`EXPERIMENT` in `config.py`).
  - The models are warmed up on train questions only.
- **Model checks.** Before and after each run, the runner checks that every model is still loaded with the right context size and `keep_alive`.
  - If a model was unloaded during a run, the run is marked `invalid` and the models are reloaded.
  - This happens, for example, when someone sends a request without `keep_alive`.
- **Thresholds.** The cascade and MF thresholds are chosen the same way, on calibration (train) data only: the cheapest threshold that reaches 95% of always-large's accuracy (`CALIBRATION_QUALITY_TARGET`). Eval labels are never used to choose thresholds or MF parameters. Each benchmark has its own MF artifact and its own thresholds.
- **Cut-off answers.** The cascade never accepts an answer that was cut off by the token limit.

## Tests

```bash
python -m unittest discover -s tests -t .
```

## Notes

- **EnergiBridge interval unit.** In EnergiBridge 0.0.7, `-i` is in milliseconds, although its help text says microseconds.
- **EnergiBridge summary.** The summary joules (`eb_summary_joules` in the manifest) are **CPU only**: in the pilot they matched the `CPU_ENERGY (J)` counter, and they leave out the GPUs. The primary energy metric, `mean_j_per_query`, integrates `GPU*_POWER (mW)` × `Delta` from `energy.csv` and divides by the number of evaluated queries. The summary line is also missing when the command fails.
- **Model placement.** Ollama splits `qwen3.5:27b` over both GPUs even when it is loaded alone. The placement is the same after every reload and is recorded in the manifest.
- **Shared machine.** EnergiBridge measures the whole machine, so reserve it while an experiment runs.
