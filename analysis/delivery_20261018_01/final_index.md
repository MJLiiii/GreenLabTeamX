# Final delivery index

Links follow the published repository layout. Raw inputs are distributed as separate Release assets and must be prepared as instructed before a full run. file_index.csv retains original delivery-snapshot paths/transfer SHA-256, not current hashes of these updated instructions; historical verification records retain their original meaning.

|File  |Contents  |
|---|---|
| [README.md](README.md) |Installation, input acquisition and commands  |
| [methods.md](methods.md) |Retained methods and limitations  |
| [data_dictionary.md](data_dictionary.md) |Approved query-processing dictionary  |
| [analysis/portable_20261018/main.R](../portable_20261018/main.R) |Recommended portable entry  |
| [analysis/portable_20261018/static/assets.csv](../portable_20261018/static/assets.csv) |Hashes of 12 modules and static evidence  |
| [analysis/portable_20261018/static/input_hashes.csv](../portable_20261018/static/input_hashes.csv) |261 required raw files  |
| [raw_input_location.json](raw_input_location.json) |Location and acquisition of excluded raw inputs  |
| [analysis/portable_reproduced_20261018_01/processing/query_metrics.csv](../portable_reproduced_20261018_01/processing/query_metrics.csv) |10000 query-repeat records  |
| [analysis/portable_reproduced_20261018_01/processing/question_summary.csv](../portable_reproduced_20261018_01/processing/question_summary.csv) |2000 question-strategy summaries  |
| [analysis/portable_reproduced_20261018_01/processing/run_reconciliation.csv](../portable_reproduced_20261018_01/processing/run_reconciliation.csv) |55 reconciliations  |
| [analysis/portable_reproduced_20261018_01/processing/idle_summary.csv](../portable_reproduced_20261018_01/processing/idle_summary.csv) |Five idle records  |
| [analysis/portable_reproduced_20261018_01/descriptive/continuous_summary.csv](../portable_reproduced_20261018_01/descriptive/continuous_summary.csv) |Main descriptive table; remaining tables retained alongside  |
| [analysis/portable_reproduced_20261018_01/inference/all_primary_tests.csv](../portable_reproduced_20261018_01/inference/all_primary_tests.csv) |54 primary comparisons  |
| [analysis/portable_reproduced_20261018_01/inference/hac_sensitivity.csv](../portable_reproduced_20261018_01/inference/hac_sensitivity.csv) |120 HAC records  |
| [analysis/portable_reproduced_20261018_01/sensitivity/sensitivity_point_estimates.csv](../portable_reproduced_20261018_01/sensitivity/sensitivity_point_estimates.csv) |420 sensitivity estimates  |
| [analysis/portable_reproduced_20261018_01/figures_index.md](../portable_reproduced_20261018_01/figures_index.md) |30 final PDF/PNG pairs  |
| [analysis/portable_reproduced_20261018_01/history_comparisons.csv](../portable_reproduced_20261018_01/history_comparisons.csv) |24-table, 733-field comparisons  |
| [analysis/portable_reproduced_20261018_01/dependencies.csv](../portable_reproduced_20261018_01/dependencies.csv) |Actual six-package versions  |
| [analysis/portable_reproduced_20261018_01/sessionInfo.txt](../portable_reproduced_20261018_01/sessionInfo.txt) |Actual R session  |
| [delivery_verification/execution.json](verification/execution.json) |Actual command, exit0 and single execution  |
| [delivery_verification/acceptance_summary.json](verification/acceptance_summary.json) |Counts, missingness and numerical acceptance  |
| [delivery_verification/current_data_lineage.json](verification/current_data_lineage.json) |Actual new downstream inputs and hashes  |
| [delivery_verification/figure_comparisons.csv](verification/figure_comparisons.csv) |30-PNG and 30-PDF identity checks  |
| [delivery_verification/final_protection.json](verification/final_protection.json) |Original-file protection  |
| [delivery_verification/package_copy_checks.csv](verification/package_copy_checks.csv) |Source/package byte-hash checks  |
| [file_index.csv](file_index.csv) |Package inventory and hashes excluding itself  |

| [Per-file remote verification](verification/remote_verification.csv) |261 paths, blobs and byte statuses  |
| [Remote differences](verification/raw_differences.csv) |160 newline-only differences  |
| [Remote verification method](verification/remote_report.md) |Fixed commit and evidence scope  |

## Raw archive and byte preservation

The raw ZIP is published as a [Release](https://github.com/MJLiiii/GreenLabTeamX/releases/tag/assignment3-reproducibility-v1.0.0) asset outside the Git tree: [download ZIP](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip), [download SHA-256 sidecar](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/raw_archive.sha256). Actual downloads passed verification on 2026-10-18; the tag remains at `db646bf8fade1c43466e6986e62ad3a54df2336a`. Repository guidance and historical member checks follow; no analysis rerun or cross-machine numerical reproduction was performed.

|File  |Contents  |
|---|---|
| [Archive metadata](raw_archive.json) |Name, size, SHA-256 and published status  |
| [Archive SHA-256](raw_archive.sha256) |Also published as the Release checksum asset  |
| [261 existing member checks](verification/raw_archive_verification.csv) |Reused decompressed-member verification  |
| [Byte preservation instructions](byte_preservation.md) |Extraction, verification and25-path scope  |
| [Offline archive verifier](tools/verify_raw_archive.py) |Independent verification without analysis  |
| [Published attribute rules](../../.gitattributes) |Published25-path rules; unchanged in this update  |
