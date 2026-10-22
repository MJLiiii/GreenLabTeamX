# Green Lab shareable reproduction delivery

The [Assignment 3 Release](https://github.com/MJLiiii/GreenLabTeamX/releases/tag/assignment3-reproducibility-v1.0.0) was publicly published at 2026-10-18T01:19:25Z. Tag `assignment3-reproducibility-v1.0.0` resolves to full commit `db646bf8fade1c43466e6986e62ad3a54df2336a` ([fixed-version code](https://github.com/MJLiiii/GreenLabTeamX/tree/db646bf8fade1c43466e6986e62ad3a54df2336a)). Both assets were downloaded and verified on 2026-10-18; this update only fills documentation links/publication metadata, without rerunning analysis, extracting files or repeating the261-member check. Pending-publication statements in historical review snapshots retain their original meaning; this guide is the current acquisition entry. The documentation follow-up does not move the release tag.

## Status and entry

The recommended entry is [analysis/portable_20261018/main.R](../portable_20261018/main.R). One complete run on the original workstation exited R with code 0; all 24 reference tables and 733 field checks passed with maximum numerical difference 0, identical missingness and Holm decisions. Outputs contain 10,000 query rows, 2,000 question summaries, 54 primary comparisons, 120 HAC records and 420 sensitivity estimates. This is not cross-machine validation; no new experiment or manuscript change was made. See the [final index](final_index.md).

## Obtaining original inputs

Download the [raw-input ZIP](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip) and [raw_archive.sha256](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/raw_archive.sha256) from the Release. ZIP `GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip` is 233,299,533 bytes, SHA-256 `a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b`. Both actual downloads returned HTTP 200; independently reading the downloaded ZIP confirmed its size/SHA-256 against the locally approved record. The123-byte sidecar matches the approved bytes, filename and hash. The ZIP contains exactly the261 files in the [approved manifest](../portable_20261018/static/input_hashes.csv), retaining results/main/ paths. Previous member-size, SHA-256 and CRC stream checks passed; only the attachments were checked this time. The ZIP remains a separate Release asset outside ordinary Git history.

After acquisition, check the archive SHA-256, then follow [verification/extraction steps](byte_preservation.md) to verify all261 members and extract under the project root, creating results/main/. Stop if results/main already exists and use a new copy, without overwriting historical data. See [raw_archive.json](raw_archive.json), [per-file verification](verification/raw_archive_verification.csv) and [raw-input location](raw_input_location.json). The earlier archive stage verified member bytes in memory streams; this download verification performed no extraction.

The previous fixed-commit remote review remains101 byte-identical files and160 CRLF/LF differences; it was not repeated. A full remote download does not replace this approved local-byte snapshot. Future Git newline/filter/encoding conversion can affect pinned code/static hashes; see the25-path policy and historical review limits in [byte-preservation guidance](byte_preservation.md). The rules are included in the published root .gitattributes; this update changes no rules, input hashes or originals and runs no analysis.

If a Git repository copy already contains remote LF results/main, do not extract over it. Create a separate empty reproduction workspace, copy the listed analysis code/static evidence and required references with their relative layout, omit existing results/main, then extract the archive under that new root. This preserves repository history and restores approved bytes. Listed transfer SHA-256 values describe source copies only; text outside the25 attribute rules has no guaranteed post-checkout SHA-256 identity.

## Dependency installation

Standard R library discovery is used. The verified session used R 4.6.1; see [dependencies.csv](../portable_reproduced_20261018_01/dependencies.csv) and [sessionInfo.txt](../portable_reproduced_20261018_01/sessionInfo.txt). There is no personal library, automatic installation, global configuration change or unverified lockfile. If needed, run the following in an R console; installing newer versions alone does not establish numerical reproduction.

```r
p <- c("data.table","ggplot2","jsonlite","digest","sandwich","zoo")
missing <- p[!vapply(p, requireNamespace, logical(1), quietly=TRUE)]
if(length(missing)) install.packages(missing, repos="https://cloud.r-project.org")
```

## Execution

Set the PowerShell variable to the extracted project root and use Rscript from PATH or its local executable path. Output must not exist and inputs stay read-only. Commands below are alternatives: environment/path checks only, ordinary reproduction, or explicit historical comparison; do not run all three full modes in sequence. After restoring raw inputs, the last command reproduces this acceptance procedure. The 24 reviewed reference CSVs are included; old figures and failed attempts are excluded.

```powershell
$projectRoot = "D:/path/to/GreenLabTeamX"
Rscript --vanilla "$projectRoot/analysis/portable_20261018/main.R" --root "$projectRoot" --check-only
Rscript --vanilla "$projectRoot/analysis/portable_20261018/main.R" --root "$projectRoot" --out analysis/new_run_01
Rscript --vanilla "$projectRoot/analysis/portable_20261018/main.R" --root "$projectRoot" --out analysis/new_compare_01 --compare-history --reference analysis/reproduced_20261018_03
```

The entry and 12 modules retain their original project-relative structure and bytes; configuration/static hashes also match their originals. Historical comparison is explicitly optional; ordinary execution does not depend on historical numerical results. Every run creates a fresh inventory and SHA-256 protection; historical task inventories, a personal workspace and old test fixtures are not prerequisites. Do not write logs or package files inside the project while R is running: capture logs outside and move them in only after R's protection finishes. See the actual [execution record](verification/execution.json) and [console](verification/execution_console.log).

## Acceptance scope and interpretation limits

The unique missing-tail energy NA and four-valid-repeat summary remain; correctness and latency retain five repeats. All 30 PNGs are byte-identical to the reviewed corrected references; all 30 PDFs are byte-identical except creation/modification date metadata, so no differing figure required a new visual inspection. Four startup C.UTF-8 locale warnings remain in the log and did not block execution. See [methods.md](methods.md) and [data_dictionary.md](data_dictionary.md). Numerical reproduction does not remove existing shared-run dependence or uncertainty about future reruns.

[file_index.csv](file_index.csv) records original delivery-snapshot targets and transfer SHA-256, excluding itself; it is not a current hash list for these updated instructions and remains unchanged as a historical index. Only this successful result and required references are included, without personal libraries, workspace files, old faulty figures or failed outputs. See [final_protection.json](verification/final_protection.json). To keep sharing concise, full workspace protection inventories remain in the source project rather than the archive. Recorded original paths and creation times are provenance, not portability prerequisites.
