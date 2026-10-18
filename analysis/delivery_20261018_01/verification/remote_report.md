# 远端原始输入核对 / Remote original-input verification

## 固定状态与方法 / Fixed state and method

中文：默认分支main，固定[commit](https://github.com/MJLiiii/GreenLabTeamX/commit/8f3765b00a646e1288f4ad6e657a82a3dbf89e61)为8f3765b00a646e1288f4ad6e657a82a3dbf89e61。首次沙箱代理连接失败，未当作缺失；随后只读ls-remote成功。远端公告commit与本地已有对象相同，重新计算commit及58个相关tree对象SHA-1后，以cat-file/ls-tree读取不可变树的blob ID，未fetch、下载原始负载或写Git。Git blob ID按SHA1("blob "+字节长度+NUL+原字节)计算，与远端同类ID比较；输入SHA-256仅与批准清单比较，不与Git ID混用。

English: The default branch is main at fixed [commit](https://github.com/MJLiiii/GreenLabTeamX/commit/8f3765b00a646e1288f4ad6e657a82a3dbf89e61), 8f3765b00a646e1288f4ad6e657a82a3dbf89e61. Initial sandbox proxy failure was not counted as missing; subsequent read-only ls-remote succeeded. The advertised commit equals an existing local object; commit and58 relevant tree SHA-1 identities were recomputed before reading blob IDs with cat-file/ls-tree, without fetch, raw payload downloads or Git writes. Git blob IDs are SHA1("blob "+byte_length+NUL+raw_bytes), compared only with the same remote Git object type. Input SHA-256 is compared only against the approved manifest, never against Git IDs.

## 结果与影响 / Results and impact

中文：261项全部存在：101项原字节一致（manifest1、queries50、calls50），160项仅换行不同（energy55、summary55、run.json50）。本地261项SHA-256及大小全部符合批准清单；160项CRLF→LF后Git blob ID逐项匹配远端。没有缺失、LFS指针或未核实项。LF等价不是原字节一致，远端完整下载不能直接被宣称可通过现有输入SHA-256门槛。未改变原文件、配置、评分、方法、统计结果或有效性解释。

English: All261 paths exist:101 are raw-byte identical (manifest1, queries50, calls50), while160 differ only in newline bytes (energy55, summary55, run.json50). All261 local SHA-256 values/sizes match the approved manifest; converting CRLF to LF only in diagnostic memory reproduces each of the160 remote blob IDs. No path is missing, an LFS pointer or unverified. LF equivalence is not original-byte identity: a complete remote download cannot be claimed to satisfy existing input SHA-256 gates. No original file, configuration, scoring, method, statistical result or validity interpretation changed.

## 获取与存放建议 / Acquisition and storage recommendation

中文：核对CSV提供固定commit的blob链接和raw URL；只核对commit中目标路径，不声称逐URL HTTP或匿名访问已验证。101份可按固定URL取得，160份仍需Shiyuan现有字节快照。建议在后续授权后单独保存字节不变数据归档、公布归档SHA-256和获取位置，不覆盖results/main、不改现有input_hashes.csv。新归档尚未创建，远端全部LF文件不列为待覆盖上传。

English: The verification CSV provides fixed-commit blob links and raw URLs. Paths in the commit are checked; individual HTTP or anonymous-access success is not claimed. Obtain101 matching files through fixed URLs and the other160 from Shiyuan's existing byte-exact snapshot. With later authorization, store a separate immutable byte-exact archive with its SHA-256 and acquisition location; do not replace results/main or change input_hashes.csv. No new archive exists, and remote LF files are not scheduled for replacement.

## 清单、导航与限制 / Manifest, navigation and limits

中文：上传清单仅为待审方案，尚未上传。根README只追加双语导航，原项目介绍逐字节保留；交付README、methods、数据字典、索引和证据放analysis/delivery_20261018_01，模块保留原相对路径。排除根AGENTS替换、旧ZIP、原ZIP清单、个人库、失败尝试、旧错误图及展开包重复副本。后续上传前应重新核对远端是否变化并取得授权；本轮未重跑分析、实验、检验或绘图。

English: The upload manifest is a review-only proposal; nothing has been uploaded. Root README receives only appended bilingual navigation, preserving its original introduction bytes. Delivery README, methods, dictionary, index and evidence go under analysis/delivery_20261018_01, with module-relative paths retained. Root AGENTS replacement, old ZIP/archive inventory, personal libraries, failed attempts, faulty figures and duplicate expanded copies are excluded. Recheck remote changes and obtain authorization before later upload. No analysis, experiment, test or plot was rerun here.
