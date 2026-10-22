# Sensitivity point-estimate reproduction

## Sources and execution

This stage recalculates the 60 fixed sensitivity specifications as 420 point estimates from this reproduction run's newly generated query_metrics.csv, question_summary.csv and run_reconciliation.csv. The static specification is analysis/portable_20261018/static/comparison_plan.csv. Historical pure functions are loaded into an isolated environment for pairing and point estimation only. No historical 420-row numeric output is read or copied, and full diagnostics, historical tests and formal inference are not executed.

## Retained rules

The output retains 14 left-hold scenarios, four bilateral query3030 exclusions, two combined scenarios and 400 one-sided whole-run omissions. MMLU small_only energy omissions always use the same 199-question all-run reference after excluding query3030 from both sides. Each scenario omits one actual run from A or B, never both sides with a matching repetition label. Latency uses original latency_ms/1000 seconds. Relative changes near a zero reference follow the established not-applicable rule while original-unit changes are retained.

## Records

source_hashes.csv records SHA-256 for the new inputs, historical pure-function module, static specification and this adapter; provenance.json records scope and unchanged-input verification. Existing files remain read-only and the output directory must not exist. The table contains sensitivity point estimates only, without p-values, inferential intervals or standardized effects.
