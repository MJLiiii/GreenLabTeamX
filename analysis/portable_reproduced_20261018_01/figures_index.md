# 图表索引 / Figure index

中文：图表使用本次计算结果；推断区间为未调整逐比较95%，Holm判断单独显示。

English: Figures use this run's calculations; inferential intervals are unadjusted pointwise 95% with separate Holm decisions.

## mmlu_pro_energy_distribution

[PNG](descriptive/figures/mmlu_pro_energy_distribution.png) · [PDF](descriptive/figures/mmlu_pro_energy_distribution.pdf)

中文：每题跨重复均值的 GPU、CPU gross 能耗分布；两面板纵轴分别缩放。

English: GPU and CPU gross-energy distributions of question means; panels use separate vertical scales.

## mmlu_pro_latency_distribution

[PNG](descriptive/figures/mmlu_pro_latency_distribution.png) · [PDF](descriptive/figures/mmlu_pro_latency_distribution.pdf)

中文：每题五次单调计时延迟均值分布，毫秒除以1000换成秒，包含整个 query。

English: Distribution of five-repeat question latency means, converted from milliseconds to seconds; full query window.

## mmlu_pro_run_means

[PNG](descriptive/figures/mmlu_pro_run_means.png) · [PDF](descriptive/figures/mmlu_pro_run_means.pdf)

中文：各策略五次运行均值；横向小位移对应 repetition 1至5，三角形标明能耗分母199。

English: Five run means per strategy; horizontal offsets identify repetitions 1 to 5; a triangle marks energy denominator 199.

## mmlu_pro_accuracy

[PNG](descriptive/figures/mmlu_pro_accuracy.png) · [PDF](descriptive/figures/mmlu_pro_accuracy.pdf)

中文：多数正确性、五次运行准确率和平均运行准确率分别显示；无推断性区间。

English: Majority correctness, five individual run accuracies and mean run accuracy are displayed separately, without inferential intervals.

## mmlu_pro_energy_accuracy

[PNG](descriptive/figures/mmlu_pro_energy_accuracy.png) · [PDF](descriptive/figures/mmlu_pro_energy_accuracy.pdf)

中文：以200道题等权能耗均值及多数正确率描述权衡；不作显著性或统计支配解释。

English: Descriptive tradeoff between equal-weight mean question energy and majority accuracy over 200 questions; no significance or statistical dominance interpretation.

## mmlu_pro_final_models

[PNG](descriptive/figures/mmlu_pro_final_models.png) · [PDF](descriptive/figures/mmlu_pro_final_models.pdf)

中文：最终答案模型比例，分母为每策略1000次逐题执行；不表示1000道独立题目。

English: Final-answer model shares among 1000 query executions per strategy, not 1000 independent questions.

## mmlu_pro_quality_flags

[PNG](descriptive/figures/mmlu_pro_quality_flags.png) · [PDF](descriptive/figures/mmlu_pro_quality_flags.pdf)

中文：最终输出截断率与答案提取失败率；分母为1000次逐题执行，两类标记可能重合。

English: Final-output truncation and extraction-failure rates among 1000 query executions per strategy; flags may overlap.

## mmlu_pro_method_sensitivity

[PNG](descriptive/figures/mmlu_pro_method_sensitivity.png) · [PDF](descriptive/figures/mmlu_pro_method_sensitivity.pdf)

中文：每题均值上的积分方法差：绝对差|左保持-梯形|与相对差百分数；不代表传感器精度或正式效应量。

English: Question-mean integration differences: absolute |left hold - trapezoid| and signed relative percent; not sensor accuracy or a formal effect size.

## gsm_hard_energy_distribution

[PNG](descriptive/figures/gsm_hard_energy_distribution.png) · [PDF](descriptive/figures/gsm_hard_energy_distribution.pdf)

中文：每题跨重复均值的 GPU、CPU gross 能耗分布；两面板纵轴分别缩放。

English: GPU and CPU gross-energy distributions of question means; panels use separate vertical scales.

## gsm_hard_latency_distribution

[PNG](descriptive/figures/gsm_hard_latency_distribution.png) · [PDF](descriptive/figures/gsm_hard_latency_distribution.pdf)

中文：每题五次单调计时延迟均值分布，毫秒除以1000换成秒，包含整个 query。

English: Distribution of five-repeat question latency means, converted from milliseconds to seconds; full query window.

## gsm_hard_run_means

[PNG](descriptive/figures/gsm_hard_run_means.png) · [PDF](descriptive/figures/gsm_hard_run_means.pdf)

中文：各策略五次运行均值；横向小位移对应 repetition 1至5，三角形标明能耗分母199。

English: Five run means per strategy; horizontal offsets identify repetitions 1 to 5; a triangle marks energy denominator 199.

## gsm_hard_accuracy

[PNG](descriptive/figures/gsm_hard_accuracy.png) · [PDF](descriptive/figures/gsm_hard_accuracy.pdf)

中文：多数正确性、五次运行准确率和平均运行准确率分别显示；无推断性区间。

English: Majority correctness, five individual run accuracies and mean run accuracy are displayed separately, without inferential intervals.

## gsm_hard_energy_accuracy

[PNG](descriptive/figures/gsm_hard_energy_accuracy.png) · [PDF](descriptive/figures/gsm_hard_energy_accuracy.pdf)

中文：以200道题等权能耗均值及多数正确率描述权衡；不作显著性或统计支配解释。

English: Descriptive tradeoff between equal-weight mean question energy and majority accuracy over 200 questions; no significance or statistical dominance interpretation.

## gsm_hard_final_models

[PNG](descriptive/figures/gsm_hard_final_models.png) · [PDF](descriptive/figures/gsm_hard_final_models.pdf)

中文：最终答案模型比例，分母为每策略1000次逐题执行；不表示1000道独立题目。

English: Final-answer model shares among 1000 query executions per strategy, not 1000 independent questions.

## gsm_hard_quality_flags

[PNG](descriptive/figures/gsm_hard_quality_flags.png) · [PDF](descriptive/figures/gsm_hard_quality_flags.pdf)

中文：最终输出截断率与答案提取失败率；分母为1000次逐题执行，两类标记可能重合。

English: Final-output truncation and extraction-failure rates among 1000 query executions per strategy; flags may overlap.

## gsm_hard_method_sensitivity

[PNG](descriptive/figures/gsm_hard_method_sensitivity.png) · [PDF](descriptive/figures/gsm_hard_method_sensitivity.pdf)

中文：每题均值上的积分方法差：绝对差|左保持-梯形|与相对差百分数；不代表传感器精度或正式效应量。

English: Question-mean integration differences: absolute |left hold - trapezoid| and signed relative percent; not sensor accuracy or a formal effect size.

## forest_mmlu_pro_gpu_trapezoid_j

[PNG](inference/figures/forest_mmlu_pro_gpu_trapezoid_j.png) · [PDF](inference/figures/forest_mmlu_pro_gpu_trapezoid_j.pdf)

中文：按题目配对的 A−B 差及未调整逐比较95%区间；右列独立报告 Holm 判断。不得从区间是否跨零推定校正后判断。

English: Paired A-minus-B differences and unadjusted pointwise 95% intervals; the separate right column reports Holm decisions, which must not be inferred from interval overlap with zero.

## forest_mmlu_pro_cpu_j

[PNG](inference/figures/forest_mmlu_pro_cpu_j.png) · [PDF](inference/figures/forest_mmlu_pro_cpu_j.pdf)

中文：按题目配对的 A−B 差及未调整逐比较95%区间；右列独立报告 Holm 判断。不得从区间是否跨零推定校正后判断。

English: Paired A-minus-B differences and unadjusted pointwise 95% intervals; the separate right column reports Holm decisions, which must not be inferred from interval overlap with zero.

## forest_mmlu_pro_latency_s

[PNG](inference/figures/forest_mmlu_pro_latency_s.png) · [PDF](inference/figures/forest_mmlu_pro_latency_s.pdf)

中文：按题目配对的 A−B 差及未调整逐比较95%区间；右列独立报告 Holm 判断。不得从区间是否跨零推定校正后判断。

English: Paired A-minus-B differences and unadjusted pointwise 95% intervals; the separate right column reports Holm decisions, which must not be inferred from interval overlap with zero.

## forest_mmlu_pro_majority_correct

[PNG](inference/figures/forest_mmlu_pro_majority_correct.png) · [PDF](inference/figures/forest_mmlu_pro_majority_correct.pdf)

中文：按题目配对的 A−B 差及未调整逐比较95%区间；右列独立报告 Holm 判断。不得从区间是否跨零推定校正后判断。

English: Paired A-minus-B differences and unadjusted pointwise 95% intervals; the separate right column reports Holm decisions, which must not be inferred from interval overlap with zero.

## forest_gsm_hard_gpu_trapezoid_j

[PNG](inference/figures/forest_gsm_hard_gpu_trapezoid_j.png) · [PDF](inference/figures/forest_gsm_hard_gpu_trapezoid_j.pdf)

中文：按题目配对的 A−B 差及未调整逐比较95%区间；右列独立报告 Holm 判断。不得从区间是否跨零推定校正后判断。

English: Paired A-minus-B differences and unadjusted pointwise 95% intervals; the separate right column reports Holm decisions, which must not be inferred from interval overlap with zero.

## forest_gsm_hard_cpu_j

[PNG](inference/figures/forest_gsm_hard_cpu_j.png) · [PDF](inference/figures/forest_gsm_hard_cpu_j.pdf)

中文：按题目配对的 A−B 差及未调整逐比较95%区间；右列独立报告 Holm 判断。不得从区间是否跨零推定校正后判断。

English: Paired A-minus-B differences and unadjusted pointwise 95% intervals; the separate right column reports Holm decisions, which must not be inferred from interval overlap with zero.

## forest_gsm_hard_latency_s

[PNG](inference/figures/forest_gsm_hard_latency_s.png) · [PDF](inference/figures/forest_gsm_hard_latency_s.pdf)

中文：按题目配对的 A−B 差及未调整逐比较95%区间；右列独立报告 Holm 判断。不得从区间是否跨零推定校正后判断。

English: Paired A-minus-B differences and unadjusted pointwise 95% intervals; the separate right column reports Holm decisions, which must not be inferred from interval overlap with zero.

## forest_gsm_hard_majority_correct

[PNG](inference/figures/forest_gsm_hard_majority_correct.png) · [PDF](inference/figures/forest_gsm_hard_majority_correct.pdf)

中文：按题目配对的 A−B 差及未调整逐比较95%区间；右列独立报告 Holm 判断。不得从区间是否跨零推定校正后判断。

English: Paired A-minus-B differences and unadjusted pointwise 95% intervals; the separate right column reports Holm decisions, which must not be inferred from interval overlap with zero.

## hac_se_ratio_mmlu_pro_gpu_trapezoid_j

[PNG](inference/figures/hac_se_ratio_mmlu_pro_gpu_trapezoid_j.png) · [PDF](inference/figures/hac_se_ratio_mmlu_pro_gpu_trapezoid_j.pdf)

中文：固定 lag=5、10、20 的 HAC 与主要配对t标准误之比；右列分别展示每个 lag 的原比较族 Holm 判断。三个 lag 不构成联合错误率保证，也不用于择优。

English: Ratios of HAC to primary paired-t standard errors at fixed lags 5, 10 and 20. Separate columns show original-family Holm decisions for each lag; there is no across-lag joint guarantee and no selection of a preferred lag.

## hac_se_ratio_mmlu_pro_cpu_j

[PNG](inference/figures/hac_se_ratio_mmlu_pro_cpu_j.png) · [PDF](inference/figures/hac_se_ratio_mmlu_pro_cpu_j.pdf)

中文：固定 lag=5、10、20 的 HAC 与主要配对t标准误之比；右列分别展示每个 lag 的原比较族 Holm 判断。三个 lag 不构成联合错误率保证，也不用于择优。

English: Ratios of HAC to primary paired-t standard errors at fixed lags 5, 10 and 20. Separate columns show original-family Holm decisions for each lag; there is no across-lag joint guarantee and no selection of a preferred lag.

## hac_se_ratio_mmlu_pro_latency_s

[PNG](inference/figures/hac_se_ratio_mmlu_pro_latency_s.png) · [PDF](inference/figures/hac_se_ratio_mmlu_pro_latency_s.pdf)

中文：固定 lag=5、10、20 的 HAC 与主要配对t标准误之比；右列分别展示每个 lag 的原比较族 Holm 判断。三个 lag 不构成联合错误率保证，也不用于择优。

English: Ratios of HAC to primary paired-t standard errors at fixed lags 5, 10 and 20. Separate columns show original-family Holm decisions for each lag; there is no across-lag joint guarantee and no selection of a preferred lag.

## hac_se_ratio_gsm_hard_gpu_trapezoid_j

[PNG](inference/figures/hac_se_ratio_gsm_hard_gpu_trapezoid_j.png) · [PDF](inference/figures/hac_se_ratio_gsm_hard_gpu_trapezoid_j.pdf)

中文：固定 lag=5、10、20 的 HAC 与主要配对t标准误之比；右列分别展示每个 lag 的原比较族 Holm 判断。三个 lag 不构成联合错误率保证，也不用于择优。

English: Ratios of HAC to primary paired-t standard errors at fixed lags 5, 10 and 20. Separate columns show original-family Holm decisions for each lag; there is no across-lag joint guarantee and no selection of a preferred lag.

## hac_se_ratio_gsm_hard_cpu_j

[PNG](inference/figures/hac_se_ratio_gsm_hard_cpu_j.png) · [PDF](inference/figures/hac_se_ratio_gsm_hard_cpu_j.pdf)

中文：固定 lag=5、10、20 的 HAC 与主要配对t标准误之比；右列分别展示每个 lag 的原比较族 Holm 判断。三个 lag 不构成联合错误率保证，也不用于择优。

English: Ratios of HAC to primary paired-t standard errors at fixed lags 5, 10 and 20. Separate columns show original-family Holm decisions for each lag; there is no across-lag joint guarantee and no selection of a preferred lag.

## hac_se_ratio_gsm_hard_latency_s

[PNG](inference/figures/hac_se_ratio_gsm_hard_latency_s.png) · [PDF](inference/figures/hac_se_ratio_gsm_hard_latency_s.pdf)

中文：固定 lag=5、10、20 的 HAC 与主要配对t标准误之比；右列分别展示每个 lag 的原比较族 Holm 判断。三个 lag 不构成联合错误率保证，也不用于择优。

English: Ratios of HAC to primary paired-t standard errors at fixed lags 5, 10 and 20. Separate columns show original-family Holm decisions for each lag; there is no across-lag joint guarantee and no selection of a preferred lag.

