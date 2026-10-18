# 保留的方法与解释范围 / Retained methods and scope

## 逐题与重复汇总 / Query processing and repeat summaries

中文：GPU两卡功率合计，以Time为采样锚点线性插值、边界裁剪和梯形积分，另存原采样区间左端保持法；CPU使用边界插值累计计数器差。保留48处已登记初始化重复的后一条、7处真实初始间隔及独立CPU初始化量。完整query窗口含embedding、路由和全部cascade调用；延迟保留原单调计时，统计单位为秒。只报告gross，不作idle扣除。每题×策略五次均值，唯012_small_only__mmlu_pro__rep4/query3030缺尾2ms完整能耗为NA，其题目能耗均值用四次；部分能耗只参与覆盖窗口对账。正确性、延迟仍用五次，多数正确性为至少三次正确。

English: GPU sums two-card power, using Time anchors, linear interpolation, clipping and trapezoidal integration, with original-interval left hold retained separately. CPU uses interpolated cumulative-counter differences. Preserve the later row at 48 registered duplicate initializations, seven genuine initial intervals and separate CPU initialization increments. Full query windows include embedding, routing and every cascade call; latency retains original monotonic timing and is analyzed in seconds. Energy is gross, without idle subtraction. Question-by-strategy means use five repeats except the complete energy NA for the 2ms missing tail at 012_small_only__mmlu_pro__rep4/query3030: that energy mean uses four. Covered energy is only for window reconciliation. Correctness/latency use five repeats; majority correctness requires at least three correct.

## 已批准推断 / Approved inference

中文：静态[方法配置](../portable_20261018/static/method_config.json)与[比较清单](../portable_20261018/static/comparison_plan.csv)保持不变。连续指标按benchmark、query_id配对题目跨重复均值，采用已批准的双侧配对t；多数正确性采用exact McNemar与Newcombe 10区间。四个Holm族为24/12/6/12；alpha=0.05，区间为未调整的逐比较95%，不称同时区间。连续效应按既有均值差、相对差及Cohen dz定义；准确率差为百分点。固定HAC采用真实题序、Bartlett、lag5/10/20、非prewhite及原调整设定，仅为既定敏感性分析；未针对三个lag提供联合多重性保证。60个敏感性规范展开420条点估计，保持左端法、双方排除3030和单边留一run规则。未按结果改变评分、阈值、方向或排除。

English: The static [method configuration](../portable_20261018/static/method_config.json) and [comparison plan](../portable_20261018/static/comparison_plan.csv) are unchanged. Continuous question repeat-means are paired by benchmark/query_id using approved two-sided paired t inference; majority correctness uses exact McNemar and Newcombe 10 intervals. Holm families have 24/12/6/12 tests; alpha is 0.05, and intervals are unadjusted pointwise 95%, not simultaneous. Continuous effects retain mean differences, relative changes and Cohen dz; accuracy differences use percentage points. Fixed HAC uses actual question order, Bartlett, lags5/10/20, no prewhitening and the original adjustment, only as established sensitivity analysis, without a joint multiplicity guarantee across lags. The 60 sensitivity specifications expand into 420 estimates, retaining left hold, bilateral query3030 exclusion and one-sided run omission. No results-driven scoring, threshold, direction or exclusion changes were made.

## 适用范围与历史文档 / Scope and historical documents

中文：目标限于已记录运行、固定配置和冻结题目组成下的条件性比较。五次重复不是1,000个独立题目，相同repetition不自动构成运行配对区组；题目配对、Holm和HAC不消除共同运行影响，也不估计未来重跑不确定性。多数正确性不是答案文本投票或运行准确率均值。“不显著”不等于等效；95%校准目标不是非劣效界值。方案形成于查看数据之后，不是实验前预注册。原AGENTS中的旧run-level Welch及待批准叙述作为历史材料原样保留；本次执行用户随后确认的方法配置，不回写旧文档。

English: The target is conditional comparison under recorded runs, fixed configuration and frozen question composition. Five repeats are not 1,000 independent questions, and matching repetition labels do not define paired run blocks. Question pairing, Holm and HAC neither remove shared-run effects nor estimate future-rerun uncertainty. Majority correctness is not answer-text voting or mean run accuracy. Nonsignificance is not equivalence, and the 95% calibration target is not a noninferiority margin. The plan was formed after viewing data, not preregistered before experiments. Historical run-level Welch/pending-approval statements in AGENTS are preserved verbatim; this execution follows the subsequently user-approved configuration without rewriting old documents.

## 本次复现检查 / Current reproduction checks

中文：仅运行一次完整链及必需不变量、历史数值对照和图像一致性检查，没有重跑旧单元测试或完整诊断。一般数值容差1e-10+1e-10×abs(reference)，p值1e-15+1e-9×abs(reference)；缺失和Holm决定严格一致。实际所有数值差为0。PDF比较只去除CreationDate/ModDate字段后对全部剩余字节作一致性检查，不是重新绘图，也不是新的实际视觉审查。

English: One full chain was executed with necessary invariants, historical numerical comparisons and image-identity checks, without repeating historical unit tests or full diagnostics. General tolerance is 1e-10+1e-10×abs(reference), and p-value tolerance is 1e-15+1e-9×abs(reference); missingness and Holm decisions match exactly. All observed numerical differences were zero. PDF comparison removes only CreationDate/ModDate fields before comparing every remaining byte; it is neither replotting nor a new actual visual review.
