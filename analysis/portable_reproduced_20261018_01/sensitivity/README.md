# 敏感性点估计复现 / Sensitivity point-estimate reproduction

## 来源与执行 / Sources and execution

中文：本阶段从本轮新生成的query_metrics.csv、question_summary.csv和run_reconciliation.csv重新计算60个既定敏感性规范，展开420条点估计。静态比较清单来自analysis/portable_20261018/static/comparison_plan.csv。只在隔离环境载入旧模块的纯函数定义，调用配对和点估计函数；没有读取或复制旧420条数值，没有执行完整诊断、旧测试或正式推断。

English: This stage recalculates the 60 fixed sensitivity specifications as 420 point estimates from this reproduction run's newly generated query_metrics.csv, question_summary.csv and run_reconciliation.csv. The static specification is analysis/portable_20261018/static/comparison_plan.csv. Historical pure functions are loaded into an isolated environment for pairing and point estimation only. No historical 420-row numeric output is read or copied, and full diagnostics, historical tests and formal inference are not executed.

## 不变规则 / Retained rules

中文：14条左端保持、4条双方排除query3030、2条结合以及400条单边留一整run场景均保留。涉及MMLU small_only能耗的留一run始终使用双方排除query3030后的相同199题参考；每次仅省略A或B一个真实run，不按同rep同时删两方。延迟使用原latency_ms/1000秒。近零参考值的相对变化按既定规则标为不适用，原单位变化始终保留。

English: The output retains 14 left-hold scenarios, four bilateral query3030 exclusions, two combined scenarios and 400 one-sided whole-run omissions. MMLU small_only energy omissions always use the same 199-question all-run reference after excluding query3030 from both sides. Each scenario omits one actual run from A or B, never both sides with a matching repetition label. Latency uses original latency_ms/1000 seconds. Relative changes near a zero reference follow the established not-applicable rule while original-unit changes are retained.

## 记录 / Records

中文：source_hashes.csv记录新输入、旧纯函数模块、静态清单和本适配代码的SHA-256；provenance.json记录执行范围与保护核验。所有已有文件保持只读，输出目录必须不存在。该表仅含敏感性点估计，不含p值、推断区间或标准化效应量。

English: source_hashes.csv records SHA-256 for the new inputs, historical pure-function module, static specification and this adapter; provenance.json records scope and unchanged-input verification. Existing files remain read-only and the output directory must not exist. The table contains sensitivity point estimates only, without p-values, inferential intervals or standardized effects.
