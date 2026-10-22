# GreenLabTeamX: energy and accuracy of LLM routing

We compare five LLM routing strategies on MMLU-Pro and GSM-Hard, measuring accuracy, latency and GPU energy.

## Quick start

With **R and Python 3** installed, run these commands in Bash from a fresh project copy:

```bash
set -e

# Get the code and install R dependencies
git clone https://github.com/MJLiiii/GreenLabTeamX.git
cd GreenLabTeamX
Rscript --vanilla -e 'install.packages(c("data.table", "ggplot2", "jsonlite", "digest", "sandwich", "zoo"), repos="https://cloud.r-project.org")'

# Download, check and unpack the recorded measurements
curl -fL https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip -o raw_inputs.zip
echo 'a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b  raw_inputs.zip' | shasum -a 256 -c -
test ! -e results/main_checkout_backup
mv results/main results/main_checkout_backup
python3 -m zipfile -e raw_inputs.zip .

# Check the setup and generate tables and figures
Rscript --vanilla analysis/portable_20261018/main.R --root . --check-only
Rscript --vanilla analysis/portable_20261018/main.R --root . --out analysis/ta_reproduction_01
```

Results and figures: `analysis/ta_reproduction_01/README.md` and `analysis/ta_reproduction_01/figures_index.md`.

## Setup and workflow details

The quick start regenerates the reported tables and figures from saved measurements. It requires no GPU, Ollama or EnergiBridge. To collect new measurements, see [Run the experiment again](#run-the-experiment-again).

### 1. Code and dependencies

Clone into a new directory and install the six R packages. The commands use Git, curl and `shasum`, in addition to R and Python 3. `set -e` stops the command sequence if a step fails.

### 2. Recorded measurements

The download is about 233 MB and expands to 1.30 GB. The checksum command verifies the ZIP before extraction. The checked-out `results/main/` folder is preserved as `results/main_checkout_backup/`; the guard stops if that backup already exists. Use a fresh clone for these preparation commands.

The archive preserves the exact original bytes required by the analysis. A Git checkout can change CSV line endings. More verification and Windows extraction instructions are in the [data setup guide](analysis/delivery_20261018_01/byte_preservation.md).

### 3. Analysis and outputs

The first R command checks packages and input paths; the second generates results. Keep project files unchanged while R runs. Once the data is prepared, repeat only the analysis command with a new output directory:

```bash
Rscript --vanilla analysis/portable_20261018/main.R --root . --out analysis/ta_reproduction_02
```

The quick-start commands use Bash on Linux/macOS. For Windows without Bash, see the [R execution commands](analysis/delivery_20261018_01/README.md#execution).

## Results and validation

The output folder contains:

| File | Contents |
| --- | --- |
| `README.md` | Links to generated results |
| `figures_index.md` | All 30 figures |
| `descriptive/continuous_summary.csv` | Energy and latency summaries |
| `inference/all_primary_tests.csv` | The 54 primary comparisons |
| `completion.json` | Successful completion and input-protection status |

A successful run records `completed: true` and `protection_passed: true` in `completion.json`.

To also compare the regenerated tables with the reference tables, run this command with an unused output name:

```bash
Rscript --vanilla analysis/portable_20261018/main.R --root . \
  --out analysis/ta_comparison_01 \
  --compare-history --reference analysis/reproduced_20261018_03
```

Every `passed` value in `history_comparisons.csv` should be `TRUE`. The previous reproduction passed 24 table comparisons and 733 field checks on the original workstation.

Expected outputs include 10,000 question executions, 2,000 question–strategy summaries, 55 runs including five idle baselines, 54 primary comparisons, 120 HAC sensitivity records and 420 sensitivity estimates.

One execution has missing complete-energy data because its trace ends before the query finishes. That energy summary uses four repetitions; accuracy and latency retain five. See the [methods](analysis/delivery_20261018_01/methods.md) and [data dictionary](analysis/delivery_20261018_01/data_dictionary.md).

The verified environment used R 4.6.1 on Windows 11. Package versions are in [dependencies.csv](analysis/portable_reproduced_20261018_01/dependencies.csv), and the full environment is in [sessionInfo.txt](analysis/portable_reproduced_20261018_01/sessionInfo.txt). Installation above does not pin versions; cross-machine reproduction has not yet been verified.

The setup check verifies packages, code/static hashes and input paths. The full run verifies raw-input hashes and checks that files outside its output folder remain unchanged. Save console logs outside the project while it runs.


## Run the experiment again

This path performs new inference and collects new energy measurements. Use a separate working copy from the analysis quick start, because fitting replaces router artifacts and the R pipeline protects its inputs.

<details>
<summary>Hardware setup and steps for collecting new measurements</summary>

### Requirements and setup

The recorded experiment ran on Linux with **Python 3.12.3 and two NVIDIA RTX 4000 Ada GPUs, each with about 20 GB VRAM**. All three Qwen models and the embedding model must remain fully resident on the GPUs. Different hardware or model versions can change answers, timing and energy.

Before starting, have:

- Python and the pinned packages in [requirements.txt](requirements.txt).
- An Ollama server reachable at `http://localhost:11434`, supporting the generation settings in [config.py](config.py), including logprobs and `think=false`.
- EnergiBridge available as `energibridge` on PATH, with permission to read CPU energy counters and NVIDIA GPU power. The recorded protocol uses EnergiBridge 0.0.7 and a 200 ms sampling interval.
- Working NVIDIA drivers and `nvidia-smi`, enough VRAM for all four models, and exclusive use of the measurement machine.

From the project root:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

ollama pull qwen3.5:4b
ollama pull qwen3.5:9b
ollama pull qwen3.5:27b
ollama pull nomic-embed-text:v1.5

ollama --version
energibridge --help
nvidia-smi
```

Start Ollama with `ollama serve` in another terminal if it is not already running as a service. Use the activated environment for every Python command below. If the server uses another address or the measurement binary has another path, update `OLLAMA_URL` or `ENERGIBRIDGE["path"]` in `config.py` as appropriate.

### 1. Keep the frozen question sets

The files in `data/` already contain **600 train and 200 held-out evaluation questions per benchmark**. Train is the calibration split; the splits are disjoint, and MMLU-Pro is stratified by category. Dataset revisions and hashes are in [data/manifest.json](data/manifest.json).

Use these files to retain the original question selection. Run `python -m scripts.prepare_data` only when intentionally creating new question sets; it downloads the source datasets and rewrites the frozen files.

### 2. Load the models and check a small run

```bash
python -m scripts.load_models
ollama ps
python -m experiment.run --router small_only --benchmark gsm_hard \
  --split train --limit 5 --out-dir results/smoke_check
```

Loading happens one model at a time, largest first. Resolve any residency warnings before proceeding: all four models must be loaded, fully on the GPUs, and kept alive. The small run checks inference and output writing; it does not collect energy measurements.

### 3. Collect calibration labels and fit the routers

Use an unused experiment ID, such as `ta_calibration_01`:

```bash
python -m experiment.run_experiment --exp-id ta_calibration_01 --split train \
  --routers small_only medium_only large_only --reps 1 --no-energy
python -m scripts.fit_routers --results results/ta_calibration_01
```

This collects 3,600 calibration answers: three models × two benchmarks × 600 questions. Energy measurement, idle runs, cooldown and warm-up are disabled for calibration by default.

Fitting writes `artifacts/mf_mmlu_pro.npz`, `artifacts/mf_gsm_hard.npz`, `artifacts/router_calibration.json` and `artifacts/threshold_sweep.csv`. Each benchmark gets its own MF model and thresholds. Threshold selection targets at least 95% of always-large's calibration accuracy using the cheapest qualifying threshold. Held-out evaluation labels are excluded.

If you want to evaluate the supplied fitted routers, skip this calibration/fitting step and retain the supplied artifacts and configuration.

### 4. Run the measured evaluation

Inspect the plan first, then run it under a new ID:

```bash
python -m experiment.run_experiment --exp-id ta_main_01 --dry-run
python -m experiment.run_experiment --exp-id ta_main_01
python -m measurement.aggregate results/ta_main_01
```

The default plan contains **50 evaluation runs plus five idle baselines**: five strategies × two benchmarks × five repetitions. Each evaluation run answers 200 questions, giving 10,000 executions in total. Runs use a fixed shuffled order, a nominal 120 s initial warm-up on train questions, a 60 s cooldown before each run and 60 s idle baselines. Runtime depends on hardware; this is a full measurement campaign.

After an interruption, resume the same saved plan, then aggregate:

```bash
python -m experiment.run_experiment --exp-id ta_main_01 --resume
python -m measurement.aggregate results/ta_main_01
```

Check `manifest.csv`: all 55 runs should have `status=done`, and evaluation runs should have 200 queries with zero errors. Inspect a run's `stdout.log` if it fails. Resume retries unfinished/invalid runs, but skips `done` and `errors` runs; inspect recorded query errors explicitly.

### Outputs and measurement rules

Each campaign is stored under `results/<exp-id>/`:

| File | Purpose |
| --- | --- |
| `experiment.json`, `manifest.csv` | Saved settings, hardware, run order and status |
| `<run>/queries.csv` | Final answer, correctness, selected model, latency and tokens per question |
| `<run>/calls.csv` | Every model call, including rejected cascade stages and MF embeddings |
| `<run>/energy.csv` | EnergiBridge CPU energy and GPU power/utilization/memory samples |
| `<run>/run.json`, `stdout.log` | Data hash, settings fingerprint, router settings and execution log |
| `<run>/summary.json`, `aggregate.csv` | Run summaries and one aggregate row per run |

All strategies use temperature 0, seed 42, `think=false`, logprobs and context length 4096. The runner checks model residency before and after each run and marks a run invalid if residency changes. Settings fingerprints prevent mixing incompatible calibration artifacts and generation settings. Cascade stages reject token-limit-truncated answers.

Keep MMLU-Pro and GSM-Hard results separate. The runner's `mean_j_per_query` is whole-run GPU energy divided by evaluated query count; EnergiBridge's printed summary is CPU energy only. The published R analysis recalculates query-level energy from timestamps with trapezoidal integration and explicit missing-tail handling. Its results therefore need not equal the runner's coarse summaries. The portable R entry is tied to the original `results/main/` inputs and approved hashes; analyzing a new campaign requires adapting its input configuration and validation evidence.

</details>

## Optional: reproduce the carbon-footprint calculation

After restoring the recorded measurements, use **Python 3.11 or later**; this calculation uses only the standard library:

```bash
python3 -m scripts.compute_sci
python3 -m unittest tests.test_compute_sci -v
```

These commands read the original `results/main/` traces, the saved `results/calibration/` settings/manifests and historical reconciliation tables. They write CSV and JSON calculation outputs to `analysis/sci_20261022/`. Run them after the R reproduction has finished; see the [SCI reproduction guide](analysis/sci_20261022/README.md).

The central recorded-campaign estimate is **9.66 kg CO2e**, while sampled evaluation SCI is **0.7373 g CO2e/query**. These use different boundaries and include disclosed modeling assumptions. The [SCI reproduction guide](analysis/sci_20261022/README.md) explains the inputs, exclusions and sensitivity analysis. Submission reports, PDFs and LaTeX packages are maintained outside this code project.

## Code and supporting documentation

| Location | Contents |
| --- | --- |
| [config.py](config.py) | Models, generation settings, sampling, repetitions and calibration parameters |
| `benchmarks/`, `routers/` | Prompts, scoring and routing strategies |
| `experiment/`, `measurement/` | Inference, model residency, measurement and aggregation |
| `scripts/` | Data preparation, model loading/stopping, fitting and SCI calculations |
| [ExperimentPlanning.md](ExperimentPlanning.md) | Experiment design and research questions |
| [Delivery guide](analysis/delivery_20261018_01/README.md) | Detailed acquisition, environment and historical verification records |
| [Final index](analysis/delivery_20261018_01/final_index.md) | Reference results and supporting evidence |

For code checks, activate the Python environment and run `python -m unittest discover -s tests -t .`. Some tests call Ollama when it is reachable; those live tests are skipped when it is unavailable.

The previous full analysis reproduction passed all 24 reference-table and 733 field comparisons on the original workstation. Numerical reproduction retains the original experiment's limitations: questions within a run share measurement conditions, and a nonsignificant difference does not establish equivalence.
