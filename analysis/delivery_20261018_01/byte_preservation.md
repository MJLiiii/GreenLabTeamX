# 原始归档与字节保留 / Raw archive and byte preservation

## 归档与当前状态 / Archive and current status

中文：归档`GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip`，233,299,533字节；SHA-256：`a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b`。261个条目的解压字节共1,302,464,394字节，逐项符合原input_hashes.csv。只用二进制读取与复制；没有解析、重写CSV/JSON、转换编码或换行。原始manifest.csv是261项之一；归档不附带新说明或校验产物。附件独立分发，不默认纳入普通Git历史，尚未上传或提供URL。

English: Archive `GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip` is 233,299,533 bytes; SHA-256 `a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b`. The261 decompressed files total1,302,464,394 bytes and individually match original input_hashes.csv. Only binary reads/copies were used: no CSV/JSON payload parsing, rewriting, encoding or newline conversion. Original manifest.csv is one of the261 inputs; no new documentation/verification outputs are inside. This is a separate distribution attachment, not ordinary Git history, and has not been uploaded or assigned a URL.

## 取得后的校验与解压 / Verification and extraction after acquisition

中文：先由授权分发取得ZIP与可信校验值。以下PowerShell命令是供取得后的使用者执行的说明，本轮未执行向磁盘解压。项目根目录应包含可移植入口与批准清单；results/main必须不存在。Python校验工具仅使用标准库，是可选独立归档检查工具，不是R分析的新依赖。

English: Obtain the ZIP and trusted checksum through authorized distribution. These PowerShell commands are instructions for recipients; filesystem extraction was not performed in this task. The project root must contain the portable entry/approved manifest, with no existing results/main. The Python verifier uses only the standard library and is an optional independent archive tool, not a new R-analysis dependency.

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
