# Raw archive and byte preservation

## Archive and current status

Archive `GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip` is 233,299,533 bytes; SHA-256 `a80b2f7bcb059276eb8fea46d7944b7c698d0f1a454eb46aebb7da0c61a8294b`. The261 decompressed files total1,302,464,394 bytes and individually match original input_hashes.csv. Only binary reads/copies were used: no CSV/JSON payload parsing, rewriting, encoding or newline conversion. Original manifest.csv is one of the261 inputs; no new documentation/verification outputs are inside. The assets are published on the [Release](https://github.com/MJLiiii/GreenLabTeamX/releases/tag/assignment3-reproducibility-v1.0.0): [ZIP](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/GreenLabTeamX_raw_inputs_8f3765b_localbytes_20261018.zip) and [SHA-256 sidecar](https://github.com/MJLiiii/GreenLabTeamX/releases/download/assignment3-reproducibility-v1.0.0/raw_archive.sha256), outside ordinary Git history. Actual downloads on 2026-10-18 returned HTTP 200; ZIP size/approved SHA-256 and sidecar filename/hash matched. No extraction or repeat member check was performed. The tag remains fixed at `db646bf8fade1c43466e6986e62ad3a54df2336a` despite this documentation follow-up.

## Verification and extraction after acquisition

Download the ZIP and sidecar using the Release asset links above and compare against the approved hash on this page, rather than trusting only the accompanying sidecar. These PowerShell commands are instructions for recipients; filesystem extraction was not performed in this task. The project root must contain the portable entry/approved manifest, with no existing results/main. The Python verifier uses only the standard library and is an optional independent archive tool, not a new R-analysis dependency.

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

## Applied rules versus historical review

The25 exact-path rules in root `.gitattributes` are included in the published commit; this documentation PR changes no attributes, code or approved manifests. The following three sections preserve checks from archive preparation: draft/unapplied/unstaged statements describe that historical stage, not current publication status. Text outside the rules can still undergo newline conversion; file_index.csv retains original delivery-snapshot hashes, rather than hashes of these updated instructions.

## Existing Git configuration and risk

Current system Git config has core.autocrlf=true; core.eol, safecrlf and a custom attributesFile are not explicitly set. All188 proposed upload sources/effective attributes were inspected and still match the previous plan SHA-256. The24 runtime files comprise16 LF and8 CRLF files; globally forcing either newline style would change approved bytes. Git LFS is configured system-wide but no runtime path selects a filter, working-tree-encoding or ident conversion. System PDF diff=astextplain is display-only, not clean/smudge conversion. No filters were executed, configuration changed or remote review repeated here.

## Minimal attributes draft

The draft enumerates25 exact paths:12 computation/adapter modules, five portable R files, config.json, six static files including assets.csv/input_hashes.csv, and delivery file_index.csv. Each uses `-text !eol -filter -ident !working-tree-encoding` to disable EOL/filter/ident conversion and clear encoding conversion. There are no wildcards covering results/main, unrelated analysis files or the repository. The .gitattributes draft exists only in this task directory and is unapplied.

If Git publication is later approved, review attributes before initial inclusion of these new files and compare actual Git blobs/worktree bytes; attributes cannot recover bytes already normalized in old blobs. Deeper .gitattributes or .git/info/attributes can override rules, so future effective-attribute checks remain necessary. The draft covers runtime prerequisites and the delivery index only: other delivery text may still be converted, and a whole Git checkout is not claimed byte-identical to the old shareable ZIP.

## Limited checks and evidence

Eight checks cover the25-path set/out-of-scope controls and temporary binary copies of LF, CRLF and mixed UTF-8/ident text. The draft was checked by a restricted literal-path static parser, not applied to Git. No test repository, staging, commit or clone was created. Model checks are not actual Git conversion/clone validation. Rule semantics follow the installed Git gitattributes documentation for unset text and unspecified attributes; experimental/statistical methods are unchanged.
