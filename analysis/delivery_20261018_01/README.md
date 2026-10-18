# Green Lab 可分享复现交付 / Shareable reproduction delivery

中文：本文件为最终发布审核拟稿，尚未应用或上传。下述全量复现与261项归档验证是此前已通过的记录，本轮仅合并说明和审核发布布局。Release标签、目标提交和附件下载位置均待授权后确定。

English: This is a final publication-review draft, not applied or uploaded. Full reproduction and261-member archive validation below are previously passed records; this task only merges guidance and reviews publication layout. Release tag, target commit and download locations remain pending authorization.

## 状态与入口 / Status and entry

中文：推荐入口为 [analysis/portable_20261018/main.R](../portable_20261018/main.R)。此前在原工作站完整执行一次，实际R退出码0；24张参照表、733个字段检查通过，最大数值差0，缺失与Holm判断一致。10,000条逐题记录、2,000条题目汇总、54项主比较、120条HAC及420条敏感性点估计均已生成。不是跨机器验证；未开展新实验或修改论文。全部最终文件见[最终索引](final_index.md)。

English: The recommended entry is [analysis/portable_20261018/main.R](../portable_20261018/main.R). One complete run on the original workstation exited R with code 0; all 24 reference tables and 733 field checks passed with maximum numerical difference 0, identical missingness and Holm decisions. Outputs contain 10,000 query rows, 2,000 question summaries, 54 primary comparisons, 120 HAC records and 420 sensitivity estimates. This is not cross-machine validation; no new experiment or manuscript change was made. See the [final index](final_index.md).

## 原始输入的取得 / Obtaining original inputs

中文：已在本地制作独立的字节不变原始输入归档`GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip`，大小233,299,533字节，SHA-256为`a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b`。它包含且仅包含[批准清单](../portable_20261018/static/input_hashes.csv)中的261个文件，保留results/main/路径（包括原始manifest.csv），不含本轮说明或额外校验清单。解压流大小、SHA-256及CRC全部通过。归档未上传、无下载链接，不默认加入普通Git历史；请先经Shiyuan授权分发取得。

English: A separate byte-exact raw-input archive, `GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip`, now exists locally: 233,299,533 bytes, SHA-256 `a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b`. It contains exactly the261 files in the [approved manifest](../portable_20261018/static/input_hashes.csv), retaining results/main/ paths including original manifest.csv, with no new documentation or extra validation manifests. Every decompressed member size, SHA-256 and CRC passed. The archive is not uploaded, has no download URL and is not proposed for ordinary Git history; obtain it through authorized distribution by Shiyuan.

中文：取得后先核对整包SHA-256，再按[校验及解压步骤](byte_preservation.md)验证261项并解压到项目根目录，形成results/main/。如results/main已存在，应停止，使用新的副本，不能覆盖历史数据。归档信息见[raw_archive.json](raw_archive.json)，[逐项校验](verification/raw_archive_verification.csv)和[原始输入位置](raw_input_location.json)。本轮只在内存流验证解压字节，没有向原目录解压。

English: After acquisition, check the archive SHA-256, then follow [verification/extraction steps](byte_preservation.md) to verify all261 members and extract under the project root, creating results/main/. Stop if results/main already exists and use a new copy, without overwriting historical data. See [raw_archive.json](raw_archive.json), [per-file verification](verification/raw_archive_verification.csv) and [raw-input location](raw_input_location.json). This task verified decompressed bytes in streams without extracting into original directories.

中文：沿用此前固定commit的远端核对结论：101项原字节一致、160项CRLF/LF不同，不重复远端核对。远端完整下载不能替代这个本地字节快照。未来Git换行、过滤器或编码转换可能改变受约束代码和静态文件哈希；最小范围属性拟稿和限制见[字节保留说明](byte_preservation.md)。本轮未应用规则、改输入哈希、改原数据或重跑分析。

English: The previous fixed-commit remote review remains101 byte-identical files and160 CRLF/LF differences; it was not repeated. A full remote download does not replace this approved local-byte snapshot. Future Git newline/filter/encoding conversion can affect pinned code/static hashes; see the minimal draft policy and limits in [byte-preservation guidance](byte_preservation.md). No policy was applied, input hashes/originals changed, or analysis rerun.

中文：若Git仓库副本已经含远端LF版results/main，不要直接在其中解压。另建空的复现工作目录，仅复制本交付清单中的analysis代码、静态依据及必要参照，保留项目相对结构，不复制旧results/main；再将归档解压到该新目录根下。这样既不覆盖原仓库数据，也能取得批准的原始字节。文件传输SHA-256只约束所列源副本；25条属性规则以外的文本不能承诺Git检出后SHA-256相同。

English: If a Git repository copy already contains remote LF results/main, do not extract over it. Create a separate empty reproduction workspace, copy the listed analysis code/static evidence and required references with their relative layout, omit existing results/main, then extract the archive under that new root. This preserves repository history and restores approved bytes. Listed transfer SHA-256 values describe source copies only; text outside the25 attribute rules has no guaranteed post-checkout SHA-256 identity.

## 依赖安装 / Dependency installation

中文：使用正常R库搜索。已验证会话为R 4.6.1；六包版本见[dependencies.csv](../portable_reproduced_20261018_01/dependencies.csv)，完整会话见[sessionInfo.txt](../portable_reproduced_20261018_01/sessionInfo.txt)。无个人包库、自动安装、全局配置修改或未验证lockfile。需要时在R控制台执行以下安装命令；安装新版本本身不代表数值复现已通过。

English: Standard R library discovery is used. The verified session used R 4.6.1; see [dependencies.csv](../portable_reproduced_20261018_01/dependencies.csv) and [sessionInfo.txt](../portable_reproduced_20261018_01/sessionInfo.txt). There is no personal library, automatic installation, global configuration change or unverified lockfile. If needed, run the following in an R console; installing newer versions alone does not establish numerical reproduction.

```r
p <- c("data.table","ggplot2","jsonlite","digest","sandwich","zoo")
missing <- p[!vapply(p, requireNamespace, logical(1), quietly=TRUE)]
if(length(missing)) install.packages(missing, repos="https://cloud.r-project.org")
```

## 运行 / Execution

中文：解压后将PowerShell变量设为本包项目根目录，Rscript可使用PATH或本机可执行路径。输出目录必须不存在，所有输入保持只读。以下命令依次为仅环境/路径检查、普通复现、显式历史对照；按需选择，不需连续运行三次。原始输入恢复后，可用最后一条命令复现本次验收。已审核的24张参照CSV已包含，未包含旧图和失败尝试。

English: Set the PowerShell variable to the extracted project root and use Rscript from PATH or its local executable path. Output must not exist and inputs stay read-only. Commands below are alternatives: environment/path checks only, ordinary reproduction, or explicit historical comparison; do not run all three full modes in sequence. After restoring raw inputs, the last command reproduces this acceptance procedure. The 24 reviewed reference CSVs are included; old figures and failed attempts are excluded.

```powershell
$projectRoot = "D:/path/to/GreenLabTeamX"
Rscript --vanilla "$projectRoot/analysis/portable_20261018/main.R" --root "$projectRoot" --check-only
Rscript --vanilla "$projectRoot/analysis/portable_20261018/main.R" --root "$projectRoot" --out analysis/new_run_01
Rscript --vanilla "$projectRoot/analysis/portable_20261018/main.R" --root "$projectRoot" --out analysis/new_compare_01 --compare-history --reference analysis/reproduced_20261018_03
```

中文：入口及12个模块按原项目相对结构原样打包；配置和静态依据与原文件哈希一致。历史对照为显式可选项，普通运行不依赖历史数值。每次运行重新记录当前已有文件清单及SHA-256；历史任务清单、个人工作区和旧测试夹具不是前提。运行期间不要在项目内写日志或打包；日志可置于项目外，等R结束其保护核验后再移入。实际命令和日志见[执行记录](verification/execution.json)及[控制台](verification/execution_console.log)。

English: The entry and 12 modules retain their original project-relative structure and bytes; configuration/static hashes also match their originals. Historical comparison is explicitly optional; ordinary execution does not depend on historical numerical results. Every run creates a fresh inventory and SHA-256 protection; historical task inventories, a personal workspace and old test fixtures are not prerequisites. Do not write logs or package files inside the project while R is running: capture logs outside and move them in only after R's protection finishes. See the actual [execution record](verification/execution.json) and [console](verification/execution_console.log).

## 验收范围与解释限制 / Acceptance scope and interpretation limits

中文：唯一缺尾能耗NA及该题四次有效重复保留，正确性与延迟仍为五次。30张PNG与已审核修正版逐字节相同；30张PDF除创建/修改日期元数据外逐字节相同，因此本轮无需新增差异图视觉检查。启动的四条C.UTF-8 locale警告保留在日志中，未阻断运行。方法和解释限制见[methods.md](methods.md)；字段见[data_dictionary.md](data_dictionary.md)。共同运行影响和未来重跑不确定性的既有限制不会因数值复现而消失。

English: The unique missing-tail energy NA and four-valid-repeat summary remain; correctness and latency retain five repeats. All 30 PNGs are byte-identical to the reviewed corrected references; all 30 PDFs are byte-identical except creation/modification date metadata, so no differing figure required a new visual inspection. Four startup C.UTF-8 locale warnings remain in the log and did not block execution. See [methods.md](methods.md) and [data_dictionary.md](data_dictionary.md). Numerical reproduction does not remove existing shared-run dependence or uncertainty about future reruns.

中文：[file_index.csv](file_index.csv)记录拟交付文件的仓库目标及SHA-256（清单自身除外）。只附本次成功结果与必要参照，未纳入个人包库、工作区文件、旧错误图或失败输出。全项目前后保护证明见[final_protection.json](verification/final_protection.json)；出于精简，包中不复制全工作区的逐文件保护清单，原始核验清单仍保留在源项目中。原始路径和创建时间等字段是来源记录，不是移植前提。

English: [file_index.csv](file_index.csv) records repository delivery targets and SHA-256, excluding itself. Only this successful result and required references are included, without personal libraries, workspace files, old faulty figures or failed outputs. See [final_protection.json](verification/final_protection.json). To keep sharing concise, full workspace protection inventories remain in the source project rather than the archive. Recorded original paths and creation times are provenance, not portability prerequisites.
