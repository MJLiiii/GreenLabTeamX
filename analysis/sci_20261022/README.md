# SCI calculation

This directory contains the reproducible carbon-footprint calculation outputs, assumptions, exclusions and sources. Submission reports, PDFs and LaTeX packages are maintained outside the code project.

The central **recorded-campaign subtotal is 9.6627 kg CO2e**, including modeled calibration and known protocol overhead. Of this, 7.9233 kg is operational and 1.7394 kg is allocated embodied emissions. The sampled evaluation phase has **0.737317 g CO2e/query**. These values use different boundaries. This is an estimate with disclosed assumptions and unquantified exclusions, not a complete inventory of every activity in the research project.

## Reproduce

From the repository root, with Python 3.11 or later (standard library only):

```sh
python3 -m scripts.compute_sci
python3 -m unittest tests.test_compute_sci -v
```

The first command reads about 1.27 GB of existing energy traces. It runs no inference, performs no HTTP requests and does not import experiment modules. It preserves raw data, router artifacts and earlier analysis outputs. New CSV and JSON results are confined to this directory.

For alternative parameters, copy `parameters.json` to another location, edit the copy, and use:

```sh
python3 -m scripts.compute_sci --parameters /absolute/path/to/parameters.json --output /tmp/sci-alternative
```

Alternative calculations produce the same CSV/JSON structure. Use the assumptions recorded with each output when preparing a submission on the separate document platform.

## Files and units

| File | Contents |
| --- | --- |
| `parameters.json` | All central model assumptions and their basis |
| `summary.json` | Five explicit scope totals, functional units and limitations |
| `ledger.csv` | 118 timed allocations: 55 sampled windows, 55 process edges, six calibration runs, cooldowns and initial setup |
| `stage_summary.csv` | Six nonoverlapping stage categories; sums to the campaign subtotal |
| `strategy_summary.csv` | Ten benchmark-strategy cells; evaluation SCI, observed accuracy and baseline differences |
| `sensitivity.csv` | Central model, 13 one-parameter alternatives, and combined low/high scenarios |
| `raw_trace_checks.csv` | 55 independent integrations, historical numerical agreement, current/historical hashes and newline verification |
| `input_hashes.csv` | Current byte hashes for manifests, settings, raw traces, queries and historical reconciliation/initialization inputs |
| `verification.json` | Focused test and independent accounting checks recorded after the final calculation |

`component_j` and `cpu_gpu_j` refer to CPU package plus both GPU boards, in joules. `facility_kwh` adds a 30 W allowance for other local hardware, assumed PSU efficiency and PUE. Carbon columns ending in `_g_co2e` are grams; divide by 1,000 for kg. `duration_s` is reserved duration in seconds, not CPU utilization time. `n_queries` counts actual executions, not unique questions. Empty `cpu_j` and `gpu_j` fields on modeled intervals mean separate CPU/GPU measurements are unavailable, not zero. Query counts are recorded only on sampled evaluation and modeled calibration rows; edge/cooldown/setup rows contribute emissions without additional functional units.

The evaluation-only strategy rates use the sampled windows. Main idle runs and common overhead are not assigned to individual strategies. The campaign rate amortizes its subtotal across 10,000 held-out executions and must not be compared directly with an evaluation-only strategy rate.

## What is measured and what is modeled

CPU counter and two GPU board-power traces are measured. Energy is gross. GPU power uses timestamp-based trapezoidal integration, not the runner's old `Delta` total. CPU uses package-counter differences, without adding the overlapping core counters. The initialization registry preserves the earlier approved handling: retain the later row at 48 initial duplicate timestamps and preserve seven real initial intervals. The 131.619 J of excluded untimed CPU initialization jumps stays diagnostic. The 2 ms unmetered tail of query3030 is not extrapolated. Whole-window carbon accounting is separate from the original query-level missingness rules.

The physical Netherlands location, 30 W for other hardware, PSU efficiency 0.90, PUE 1.20, four-year life and resource share 1 are assumptions. They are not recorded hardware/facility measurements. The grid factor is the published 2026 Dutch annual reporting factor (244 g/kWh plus 16 for electricity infrastructure), not a claim about measured October carbon intensity. Grid losses are already in that factor.

The embodied estimate is an aggregate proxy for a different workstation, including the actual machine's two GPUs by assumption. The proxy's use phase is removed to avoid double counting electricity; no separate GPU PCF is added. It is not a device-specific LCA for the recorded CPU/GPU configuration. Sensitivities show substantial uncertainty in this input.

Calibration has durations but no energy traces. Each of the six runs is modeled using the time-weighted CPU/GPU power of the matching strategy and benchmark in evaluation. Process edges use each run's observed mean power. Cooldowns use the pooled, duration-weighted measured idle power. Initial setup is the elapsed creation-to-first-process time less the first cooldown, modeled using evaluation's mean power. This captures the initial warm-up's actual elapsed allowance rather than assuming its nominal 120 s was exact. Later unlogged warm-ups remain unknown.

The main-protocol allocation does not assume continuous reservation through multi-hour gaps. A separate scenario allocates the remaining 45.163 hours at observed idle power and raises the recorded-campaign subtotal to 12.2163 kg. It does not count nominal cooldowns twice. No machine ownership is inferred from the existence of timestamps.

## Validation and input preservation

The computation checks run counts, successful status, query counts/errors, configuration fingerprints, initialization identities, monotonic timestamps/CPU counters and nonnegative finite power. Each raw integration must match the earlier window totals within `1e-6 + 1e-10 * abs(reference)` approximately (implemented with `math.isclose`). Unexpected changes stop execution.

All 55 current energy hashes differ from their original archive hashes because the current checkout contains LF line endings. Replacing LF with CRLF exactly recovers every historical energy-file SHA-256; the script requires either exact bytes or this newline-only identity. Current hashes are recorded separately. This is an explicit equivalence check, not a claim that current bytes equal the original archive bytes. Inputs are not rewritten.

The six focused unit tests use analytic examples to check both GPUs, milliseconds/milliwatts conversion, CPU counter allocation, initial duplicates, invalid traces, energy losses, calendar-time embodied allocation and exact newline equivalence. Additional accounting checks reconcile all stage/strategy totals and denominator definitions. Earlier inference analyses and experiment tests are not rerun because they are outside this calculation's scope.

## Sources

- [SCI specification v1.1.0](https://sci.greensoftware.foundation/): equation, boundaries, resource/time allocation and reporting rules.
- [2026 Dutch electricity factors](https://co2emissiefactoren.nl/factoren/2026/11/elektriciteit/): gridmix 0.244 kg CO2e/kWh plus 0.016 infrastructure; grid losses included.
- [Dell Precision 7960 Tower PCF](https://www.delltechnologies.com/asset/de-de/products/desktops-and-all-in-ones/technical-support/dell-precision-7960-tower-pcf-datasheet.pdf): 2,971 kg CO2e lifecycle mean; 26% non-use stages, yielding the 772.46 kg whole-workstation proxy.

All three were checked on 22 October 2026. Unlogged fitting, downloads/loading, extra warm-ups/retries, pretraining, pilot/development work, analysis, writing and remote infrastructure remain exclusions with unknown emissions. No carbon offsets or contractual green-electricity deductions are used.
