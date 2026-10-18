# 最终交付索引 / Final delivery index

中文：以下链接为已发布仓库布局。原始输入通过独立Release附件取得，按说明准备后才能全量运行。file_index.csv保留原交付快照路径和传输SHA-256，不作为本次更新说明的当前哈希；历史核验文件保留原意。

English: Links follow the published repository layout. Raw inputs are distributed as separate Release assets and must be prepared as instructed before a full run. file_index.csv retains original delivery-snapshot paths/transfer SHA-256, not current hashes of these updated instructions; historical verification records retain their original meaning.

| 文件 / File | 内容 / Contents |
|---|---|
| [README.md](README.md) | 安装、输入取得和命令 / Installation, input acquisition and commands |
| [methods.md](methods.md) | 保留方法与限制 / Retained methods and limitations |
| [data_dictionary.md](data_dictionary.md) | 已审核逐题处理数据字典 / Approved query-processing dictionary |
| [analysis/portable_20261018/main.R](../portable_20261018/main.R) | 推荐可移植主入口 / Recommended portable entry |
| [analysis/portable_20261018/static/assets.csv](../portable_20261018/static/assets.csv) | 12模块及静态依据哈希 / Hashes of 12 modules and static evidence |
| [analysis/portable_20261018/static/input_hashes.csv](../portable_20261018/static/input_hashes.csv) | 261个必需原始文件 / 261 required raw files |
| [raw_input_location.json](raw_input_location.json) | 未随包附带的原始输入位置及取得说明 / Location and acquisition of excluded raw inputs |
| [analysis/portable_reproduced_20261018_01/processing/query_metrics.csv](../portable_reproduced_20261018_01/processing/query_metrics.csv) | 10000逐题重复记录 / 10000 query-repeat records |
| [analysis/portable_reproduced_20261018_01/processing/question_summary.csv](../portable_reproduced_20261018_01/processing/question_summary.csv) | 2000题目策略汇总 / 2000 question-strategy summaries |
| [analysis/portable_reproduced_20261018_01/processing/run_reconciliation.csv](../portable_reproduced_20261018_01/processing/run_reconciliation.csv) | 55次能量对账 / 55 reconciliations |
| [analysis/portable_reproduced_20261018_01/processing/idle_summary.csv](../portable_reproduced_20261018_01/processing/idle_summary.csv) | 5次idle / Five idle records |
| [analysis/portable_reproduced_20261018_01/descriptive/continuous_summary.csv](../portable_reproduced_20261018_01/descriptive/continuous_summary.csv) | 主要描述表；同目录保留其余表 / Main descriptive table; remaining tables retained alongside |
| [analysis/portable_reproduced_20261018_01/inference/all_primary_tests.csv](../portable_reproduced_20261018_01/inference/all_primary_tests.csv) | 54项正式比较 / 54 primary comparisons |
| [analysis/portable_reproduced_20261018_01/inference/hac_sensitivity.csv](../portable_reproduced_20261018_01/inference/hac_sensitivity.csv) | 120条HAC / 120 HAC records |
| [analysis/portable_reproduced_20261018_01/sensitivity/sensitivity_point_estimates.csv](../portable_reproduced_20261018_01/sensitivity/sensitivity_point_estimates.csv) | 420条敏感性点估计 / 420 sensitivity estimates |
| [analysis/portable_reproduced_20261018_01/figures_index.md](../portable_reproduced_20261018_01/figures_index.md) | 30组最终PDF/PNG / 30 final PDF/PNG pairs |
| [analysis/portable_reproduced_20261018_01/history_comparisons.csv](../portable_reproduced_20261018_01/history_comparisons.csv) | 24表733字段对照 / 24-table, 733-field comparisons |
| [analysis/portable_reproduced_20261018_01/dependencies.csv](../portable_reproduced_20261018_01/dependencies.csv) | 实际六包版本 / Actual six-package versions |
| [analysis/portable_reproduced_20261018_01/sessionInfo.txt](../portable_reproduced_20261018_01/sessionInfo.txt) | 实际R会话 / Actual R session |
| [delivery_verification/execution.json](verification/execution.json) | 实际命令、退出码0和一次执行 / Actual command, exit0 and single execution |
| [delivery_verification/acceptance_summary.json](verification/acceptance_summary.json) | 行数、缺失及数值验收 / Counts, missingness and numerical acceptance |
| [delivery_verification/current_data_lineage.json](verification/current_data_lineage.json) | 下游实际新输入与哈希 / Actual new downstream inputs and hashes |
| [delivery_verification/figure_comparisons.csv](verification/figure_comparisons.csv) | 30PNG与30PDF一致性 / 30-PNG and 30-PDF identity checks |
| [delivery_verification/final_protection.json](verification/final_protection.json) | 本轮原文件保护 / Original-file protection |
| [delivery_verification/package_copy_checks.csv](verification/package_copy_checks.csv) | 源文件与打包副本逐字节哈希核对 / Source/package byte-hash checks |
| [file_index.csv](file_index.csv) | 共享包完整文件索引与哈希（自身除外） / Package inventory and hashes excluding itself |

| [逐文件远端核对](verification/remote_verification.csv) | 261项路径、blob、字节状态 / 261 paths, blobs and byte statuses |
| [远端差异清单](verification/raw_differences.csv) | 160项仅换行差异 / 160 newline-only differences |
| [远端核对方法](verification/remote_report.md) | 固定commit与证据范围 / Fixed commit and evidence scope |

## 原始归档与字节保留 / Raw archive and byte preservation

中文：原始ZIP已作为[Release](https://github.com/MJLiiii/GreenLabTeamX/releases/tag/assignment3-reproducibility-v1.0.0)附件发布，不在Git文件树中：[下载ZIP](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip)、[下载SHA-256侧车](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/raw_archive.sha256)。2026-10-18实际下载核验通过；标签提交为`db646bf8fade1c43466e6986e62ad3a54df2336a`，未移动。以下为仓库内说明及历史成员校验记录；没有重跑分析或验证跨机器数值复现。

English: The raw ZIP is published as a [Release](https://github.com/MJLiiii/GreenLabTeamX/releases/tag/assignment3-reproducibility-v1.0.0) asset outside the Git tree: [download ZIP](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip), [download SHA-256 sidecar](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/raw_archive.sha256). Actual downloads passed verification on 2026-10-18; the tag remains at `db646bf8fade1c43466e6986e62ad3a54df2336a`. Repository guidance and historical member checks follow; no analysis rerun or cross-machine numerical reproduction was performed.

| 文件 / File | 内容 / Contents |
|---|---|
| [归档元数据](raw_archive.json) | 名称、大小、SHA-256及已发布状态 / Name, size, SHA-256 and published status |
| [归档SHA-256](raw_archive.sha256) | 同时已发布为Release校验附件 / Also published as the Release checksum asset |
| [261项既有校验](verification/raw_archive_verification.csv) | 复用先前解压流结果 / Reused decompressed-member verification |
| [字节保留说明](byte_preservation.md) | 解压位置、校验方法及25路径范围 / Extraction, verification and25-path scope |
| [离线归档校验工具](tools/verify_raw_archive.py) | 无分析的独立校验 / Independent verification without analysis |
| [已纳入的属性规则](../../.gitattributes) | 25路径规则；本次未改动 / Published25-path rules; unchanged in this update |
