# Remote original-input verification

## Fixed state and method

The default branch is main at fixed [commit](https://github.com/MJLiiii/GreenLabTeamX/commit/8f3765b00a646e1288f4ad6e657a82a3dbf89e61), 8f3765b00a646e1288f4ad6e657a82a3dbf89e61. Initial sandbox proxy failure was not counted as missing; subsequent read-only ls-remote succeeded. The advertised commit equals an existing local object; commit and58 relevant tree SHA-1 identities were recomputed before reading blob IDs with cat-file/ls-tree, without fetch, raw payload downloads or Git writes. Git blob IDs are SHA1("blob "+byte_length+NUL+raw_bytes), compared only with the same remote Git object type. Input SHA-256 is compared only against the approved manifest, never against Git IDs.

## Results and impact

All261 paths exist:101 are raw-byte identical (manifest1, queries50, calls50), while160 differ only in newline bytes (energy55, summary55, run.json50). All261 local SHA-256 values/sizes match the approved manifest; converting CRLF to LF only in diagnostic memory reproduces each of the160 remote blob IDs. No path is missing, an LFS pointer or unverified. LF equivalence is not original-byte identity: a complete remote download cannot be claimed to satisfy existing input SHA-256 gates. No original file, configuration, scoring, method, statistical result or validity interpretation changed.

## Acquisition and storage recommendation

The verification CSV provides fixed-commit blob links and raw URLs. Paths in the commit are checked; individual HTTP or anonymous-access success is not claimed. Obtain101 matching files through fixed URLs and the other160 from Shiyuan's existing byte-exact snapshot. With later authorization, store a separate immutable byte-exact archive with its SHA-256 and acquisition location; do not replace results/main or change input_hashes.csv. No new archive exists, and remote LF files are not scheduled for replacement.

## Manifest, navigation and limits

The upload manifest is a review-only proposal; nothing has been uploaded. Root README receives only appended bilingual navigation, preserving its original introduction bytes. Delivery README, methods, dictionary, index and evidence go under analysis/delivery_20261018_01, with module-relative paths retained. Root AGENTS replacement, old ZIP/archive inventory, personal libraries, failed attempts, faulty figures and duplicate expanded copies are excluded. Recheck remote changes and obtain authorization before later upload. No analysis, experiment, test or plot was rerun here.
