# 原始归档与字节保留 / Raw archive and byte preservation

## 归档与当前状态 / Archive and current status

中文：归档`GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip`，233,299,533字节；SHA-256：`a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b`。261个条目的解压字节共1,302,464,394字节，逐项符合原input_hashes.csv。只用二进制读取与复制；没有解析、重写CSV/JSON、转换编码或换行。原始manifest.csv是261项之一；归档不附带新说明或校验产物。附件已在[Release](https://github.com/MJLiiii/GreenLabTeamX/releases/tag/assignment3-reproducibility-v1.0.0)发布：[ZIP](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip)、[SHA-256侧车](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/raw_archive.sha256)；不进入普通Git历史。2026-10-18实际下载均为HTTP 200，ZIP大小与批准SHA-256一致，侧车文件名和哈希正确；本次未解压或重复成员核验。标签固定于`db646bf8fade1c43466e6986e62ad3a54df2336a`，文档补链不移动标签。

English: Archive `GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip` is 233,299,533 bytes; SHA-256 `a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b`. The261 decompressed files total1,302,464,394 bytes and individually match original input_hashes.csv. Only binary reads/copies were used: no CSV/JSON payload parsing, rewriting, encoding or newline conversion. Original manifest.csv is one of the261 inputs; no new documentation/verification outputs are inside. The assets are published on the [Release](https://github.com/MJLiiii/GreenLabTeamX/releases/tag/assignment3-reproducibility-v1.0.0): [ZIP](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip) and [SHA-256 sidecar](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/raw_archive.sha256), outside ordinary Git history. Actual downloads on 2026-10-18 returned HTTP 200; ZIP size/approved SHA-256 and sidecar filename/hash matched. No extraction or repeat member check was performed. The tag remains fixed at `db646bf8fade1c43466e6986e62ad3a54df2336a` despite this documentation follow-up.

## 取得后的校验与解压 / Verification and extraction after acquisition

中文：使用上方Release附件链接下载ZIP和侧车，并与本页批准哈希核对，不能只信任随包侧车。以下PowerShell命令是供取得后的使用者执行的说明，本轮未执行向磁盘解压。项目根目录应包含可移植入口与批准清单；results/main必须不存在。Python校验工具仅使用标准库，是可选独立归档检查工具，不是R分析的新依赖。

English: Download the ZIP and sidecar using the Release asset links above and compare against the approved hash on this page, rather than trusting only the accompanying sidecar. These PowerShell commands are instructions for recipients; filesystem extraction was not performed in this task. The project root must contain the portable entry/approved manifest, with no existing results/main. The Python verifier uses only the standard library and is an optional independent archive tool, not a new R-analysis dependency.

```powershell
$projectRoot = "D:/path/to/GreenLabTeamX"
$rawZip = "D:/received/GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip"
if ((Get-FileHash -LiteralPath $rawZip -Algorithm SHA256).Hash.ToLowerInvariant() -ne "a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b") { throw "Archive SHA-256 mismatch" }
python -B "$projectRoot/analysis/delivery_20261018_01/tools/verify_raw_archive.py" --archive "$rawZip" --manifest "$projectRoot/analysis/portable_20261018/static/input_hashes.csv" --expected-sha256 a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b
if ($LASTEXITCODE -ne 0) { throw "Archive verification failed" }
if (Test-Path -LiteralPath "$projectRoot/results/main") { throw "Existing results/main; do not overwrite" }
Expand-Archive -LiteralPath $rawZip -DestinationPath $projectRoot
Import-Csv "$projectRoot/analysis/portable_20261018/static/input_hashes.csv" | ForEach-Object {
  $restoredFile = Join-Path $projectRoot $_.path
  if ((Get-Item -LiteralPath $restoredFile).Length -ne [long]$_.bytes -or (Get-FileHash -LiteralPath $restoredFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $_.sha256) { throw "Restored file mismatch: $restoredFile" }
}
```

## 属性规则与历史审核的区分 / Applied rules versus historical review

中文：根`.gitattributes`的25条精确路径规则已随发布提交纳入；本次文档PR不修改属性、代码或批准清单。下列三节保留归档准备阶段的历史核验记录，出现的“拟稿”“未应用”“未暂存”仅描述该阶段，不能视为当前发布状态。规则外文本仍可能换行转换；file_index.csv保留原交付快照哈希，不更新为本次说明哈希。

English: The25 exact-path rules in root `.gitattributes` are included in the published commit; this documentation PR changes no attributes, code or approved manifests. The following three sections preserve checks from archive preparation: draft/unapplied/unstaged statements describe that historical stage, not current publication status. Text outside the rules can still undergo newline conversion; file_index.csv retains original delivery-snapshot hashes, rather than hashes of these updated instructions.

## 现有Git配置与风险 / Existing Git configuration and risk

中文：当前系统Git配置为core.autocrlf=true；core.eol、safecrlf及自定义attributesFile未显式设置。已检查188项拟上传源文件及有效属性，均仍符合前轮清单SHA-256。24个运行必需文件为16个LF、8个CRLF；直接统一成LF或CRLF都会破坏部分批准字节。系统配置了Git LFS，但这些运行文件未匹配filter，working-tree-encoding和ident等也未启用。系统PDF的diff=astextplain只影响diff展示，不是clean/smudge字节转换。本轮未执行任何过滤器、修改配置或重新核对远端。

English: Current system Git config has core.autocrlf=true; core.eol, safecrlf and a custom attributesFile are not explicitly set. All188 proposed upload sources/effective attributes were inspected and still match the previous plan SHA-256. The24 runtime files comprise16 LF and8 CRLF files; globally forcing either newline style would change approved bytes. Git LFS is configured system-wide but no runtime path selects a filter, working-tree-encoding or ident conversion. System PDF diff=astextplain is display-only, not clean/smudge conversion. No filters were executed, configuration changed or remote review repeated here.

## 最小属性拟稿 / Minimal attributes draft

中文：拟稿仅逐个列出25个精确路径：12个计算/适配模块、5个可移植R文件、config.json、6个static文件（含assets.csv和input_hashes.csv），以及交付file_index.csv。每行使用`-text !eol -filter -ident !working-tree-encoding`，禁止换行/过滤器/ident转换并取消编码转换设置；无通配符，不覆盖results/main、无关analysis文件或全仓库。`.gitattributes`只在本轮目录保存拟稿，未应用。

English: The draft enumerates25 exact paths:12 computation/adapter modules, five portable R files, config.json, six static files including assets.csv/input_hashes.csv, and delivery file_index.csv. Each uses `-text !eol -filter -ident !working-tree-encoding` to disable EOL/filter/ident conversion and clear encoding conversion. There are no wildcards covering results/main, unrelated analysis files or the repository. The .gitattributes draft exists only in this task directory and is unapplied.

中文：以后若批准Git发布，需在这些新文件首次加入前审查属性，并核对实际Git blob与工作副本字节；已经被归一化的旧blob不会由属性自动恢复原字节。更深层.gitattributes或.git/info/attributes可覆盖规则，未来仍须检查有效属性。拟稿只保障运行前提和交付索引；其余交付文本可能仍被转换，不能宣称整个Git检出与旧共享ZIP逐字节一致。

English: If Git publication is later approved, review attributes before initial inclusion of these new files and compare actual Git blobs/worktree bytes; attributes cannot recover bytes already normalized in old blobs. Deeper .gitattributes or .git/info/attributes can override rules, so future effective-attribute checks remain necessary. The draft covers runtime prerequisites and the delivery index only: other delivery text may still be converted, and a whole Git checkout is not claimed byte-identical to the old shareable ZIP.

## 有限检查与依据 / Limited checks and evidence

中文：8项检查覆盖25路径集合及范围外控制、LF/CRLF/混合UTF-8和ident文本的临时二进制复制。拟稿按仅支持精确路径的静态解析器核对；没有应用拟稿给Git、初始化测试仓库、暂存、提交或克隆。不能将该模型检查称为真实Git转换或克隆验证。规则语义依据本机Git随附gitattributes官方文档的Unset text和Unspecified属性说明；不改变实验或统计方法。

English: Eight checks cover the25-path set/out-of-scope controls and temporary binary copies of LF, CRLF and mixed UTF-8/ident text. The draft was checked by a restricted literal-path static parser, not applied to Git. No test repository, staging, commit or clone was created. Model checks are not actual Git conversion/clone validation. Rule semantics follow the installed Git gitattributes documentation for unset text and unspecified attributes; experimental/statistical methods are unchanged.
