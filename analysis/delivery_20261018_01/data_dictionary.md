# 数据字典 / Data dictionary

## 通用约定 / General conventions

中文：NA 表示不可用，不是零。原文本空串保持为空；True/False 为原布尔，新增 TRUE/FALSE 为派生布尔。query 关联键为 benchmark、strategy、repetition、query_id，汇总键去除 repetition；保留 run_id。所有能源为 gross，GPU与CPU分列。

English: NA means unavailable, not zero. Original empty strings remain empty; True/False are original booleans and derived TRUE/FALSE are derived booleans. Query keys are benchmark, strategy, repetition and query_id; summary keys omit repetition. Retain run_id. All energy is gross, with separate GPU and CPU columns.

中文：complete=时间完整；approved_missing_tail_2ms=已批准的2ms尾部缺失；unexpected_missing_coverage=新缺覆盖；sensor_anomaly=传感器段异常；pass=该数值检查通过；fail/issues=存在问题。状态不代表整体 scientifically valid。

English: complete means full temporal coverage; approved_missing_tail_2ms is the approved uncovered tail; unexpected_missing_coverage is a new coverage gap; sensor_anomaly marks a sensor-segment anomaly; pass means that specific numerical check passed; fail/issues indicates a problem. No status means overall scientific validity.

## query_metrics.csv

| Field | 中文定义 | English definition |
|---|---|---|
| run_id | 原运行标识 | Original run identifier |
| query_id | 原题目 ID；按 benchmark 区分 | Original question ID; scoped by benchmark |
| benchmark | 基准名称 | Benchmark name |
| split | 原数据划分 | Original data split |
| category | 原题目类别 | Original question category |
| router | 原路由策略 | Original routing strategy |
| final_model | 最终生成模型 | Final generation model |
| models_called | 原 generate 模型序列；不含 embed | Original generate-model sequence; excludes embed |
| num_generate_calls | 原生成调用次数 | Original generation call count |
| extracted_answer | 原提取答案，不重新评分 | Original extracted answer; not rescored |
| reference | 原参考答案 | Original reference answer |
| correct | 原正确性 True/False | Original correctness True/False |
| extraction_failed | 原提取失败标志 | Original extraction-failure flag |
| truncated | 原最终输出截断标志 | Original final-output truncation flag |
| started_at_ms | 原 Unix 墙钟开始，ms | Original Unix wall-clock start, ms |
| ended_at_ms | 原 Unix 墙钟结束，ms | Original Unix wall-clock end, ms |
| latency_s | 原单调计时秒数 | Original monotonic latency in seconds |
| latency_ms | 原单调计时毫秒数 | Original monotonic latency in milliseconds |
| routing_latency_s | 原端到端减最终生成调用秒数，含先前调用和路由 | Original end-to-end minus final generation seconds, including earlier calls and routing |
| prompt_tokens_total | 原全部 generate prompt token 合计，不含 embed | Original prompt-token total across generate calls, excluding embed |
| completion_tokens_total | 原全部 generate completion token 合计 | Original completion-token total across generate calls |
| error | 原错误文本；空表示未记录错误 | Original error text; empty means no recorded error |
| strategy | manifest 策略名称 | Manifest strategy name |
| repetition | 原重复编号 1–5 | Original repetition identifier 1–5 |
| source_query_path | 相对项目根目录的来源路径 | Source path relative to the project root |
| source_query_record_index | 原 CSV 数据记录序号；以1起，不等于多行CSV物理行 | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| source_query_sha256 | 对应原文件的 SHA-256 字节哈希 | SHA-256 byte hash of the corresponding source file |
| source_call_path | 相对项目根目录的来源路径 | Source path relative to the project root |
| source_call_record_indices | 原 CSV 数据记录序号；以1起，不等于多行CSV物理行 | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| source_call_sha256 | 对应原文件的 SHA-256 字节哈希 | SHA-256 byte hash of the corresponding source file |
| source_energy_path | 相对项目根目录的来源路径 | Source path relative to the project root |
| source_energy_sha256 | 对应原文件的 SHA-256 字节哈希 | SHA-256 byte hash of the corresponding source file |
| source_manifest_record_index | 原 CSV 数据记录序号；以1起，不等于多行CSV物理行 | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| source_manifest_sha256 | 对应原文件的 SHA-256 字节哈希 | SHA-256 byte hash of the corresponding source file |
| settings_fingerprint | 历史设置指纹，不是完整provenance或模型digest | Historical settings fingerprint, not full provenance or a model digest |
| source_energy_first_record_index | 原 CSV 数据记录序号；以1起，不等于多行CSV物理行 | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| source_energy_last_record_index | 原 CSV 数据记录序号；以1起，不等于多行CSV物理行 | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| sampling_start_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| sampling_end_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| covered_start_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| covered_end_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| wall_duration_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| covered_duration_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| missing_start_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| missing_end_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| start_bracket_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| end_bracket_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| coverage_complete | 时间覆盖完整，不代表传感器精度保证 | Complete temporal coverage, not a sensor-accuracy guarantee |
| coverage_status | complete／approved_missing_tail_2ms／unexpected_missing_coverage；可追加 sensor_anomaly | complete / approved_missing_tail_2ms / unexpected_missing_coverage; may append sensor_anomaly |
| gpu_trapezoid_j | 完整窗口 GPU 线性梯形能耗，J；缺覆盖为 NA | Complete-window GPU linear-trapezoid energy, J; NA if coverage is incomplete |
| gpu_left_j | 完整窗口 GPU 原区间左保持能耗，J；缺覆盖为 NA | Complete-window GPU original-interval left-hold energy, J; NA if incomplete |
| cpu_j | 完整窗口 CPU 边界计数器差，J；缺覆盖或跨异常为 NA | Complete-window CPU boundary-counter difference, J; NA for incomplete coverage or anomalies |
| covered_gpu_trapezoid_j | 仅已覆盖部分的能耗，J；完整值NA时仍用于对账 | Energy of the covered portion only, J; used in reconciliation even when complete energy is NA |
| covered_gpu_left_j | 仅已覆盖部分的能耗，J；完整值NA时仍用于对账 | Energy of the covered portion only, J; used in reconciliation even when complete energy is NA |
| covered_cpu_j | 仅已覆盖部分的能耗，J；完整值NA时仍用于对账 | Energy of the covered portion only, J; used in reconciliation even when complete energy is NA |
| gpu_left_minus_trapezoid_j | J；sample/clipped为累计计数器或积分贡献，minus为显式差值 | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| gpu_left_vs_trapezoid_pct | 百分数；方法差为100×(left−trapezoid)/trapezoid；利用率为原样本等权均值 | Percent; method difference is 100×(left−trapezoid)/trapezoid; utilization uses equal-weight original samples |
| correct_numeric | 原正确性对应 1/0 | Original correctness encoded as 1/0 |
| call_count | 字段指定对象的实际计数 | Observed count of the object named by the field |
| generate_call_count_observed | 从关联 calls.csv 记录重新数出的 generate 调用数 | Generate-call count recomputed from linked calls.csv records |
| embedding_call_count | 字段指定对象的实际计数 | Observed count of the object named by the field |
| embedding_prompt_tokens | 对应调用类型的原token计数或可用计数；缺失不代表0 | Original token counts or availability counts for the named call kind; missing does not mean zero |
| embedding_prompt_tokens_n_available | 对应调用类型的原token计数或可用计数；缺失不代表0 | Original token counts or availability counts for the named call kind; missing does not mean zero |
| generate_tokens_link_verified | 对应调用类型的原token计数或可用计数；缺失不代表0 | Original token counts or availability counts for the named call kind; missing does not mean zero |
| call_query_link_verified | 字段所述处理／核对／有效性／原记录标志；非整体科学有效性 | Named handling/check/validity/recorded flag; not overall scientific validity |
| all_calls_inside_query | 字段所述处理／核对／有效性／原记录标志；非整体科学有效性 | Named handling/check/validity/recorded flag; not overall scientific validity |
| call_models_all | 按重复或调用顺序的分号分隔原值 | Semicolon-separated original values in repeat or call order |
| call_latency_sum_s | 秒，定义由字段对应时间窗口指定 | Seconds, for the time interval named in the field |
| query_minus_call_latency_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| gpu_method | Time 线性梯形，两卡功率之和 | Time-based linear trapezoid of summed two-GPU power |
| gpu_sensitivity_method | 原采样区间左端功率保持 | Original sampling-interval left-power hold |
| cpu_method | Time 线性计数器边界差 | Time-based linear counter boundary difference |
| energy_scope | 目标窗口的gross能耗；仍须读取coverage字段 | Gross energy for the intended window; coverage fields still apply |
| energy_sensitivity_exclude_question | 后续涉及该单元能耗比较需排除该题敏感性检查 | Future energy comparisons involving this cell need a question-exclusion sensitivity check |
| initialization_removed_from_view | 字段所述处理／核对／有效性／原记录标志；非整体科学有效性 | Named handling/check/validity/recorded flag; not overall scientific validity |

## question_summary.csv

| Field | 中文定义 | English definition |
|---|---|---|
| benchmark | 基准名称 | Benchmark name |
| strategy | manifest 策略名称 | Manifest strategy name |
| query_id | 原题目 ID；按 benchmark 区分 | Original question ID; scoped by benchmark |
| n_repetitions | 字段指定对象的实际计数 | Observed count of the object named by the field |
| repetitions | 按重复或调用顺序的分号分隔原值 | Semicolon-separated original values in repeat or call order |
| run_ids | 按重复或调用顺序的分号分隔原值 | Semicolon-separated original values in repeat or call order |
| correct_by_repetition | 按 repetitions 顺序保存原正确性 0/1 | Original 0/1 correctness in repetitions order |
| correct_n_valid | 该前缀指标的有限有效重复数 | Number of finite valid repeats for the prefixed metric |
| correct_sum | 字段指定对象的实际计数 | Observed count of the object named by the field |
| mean_correct | 重复正确性平均值，不是多数正确性 | Mean repeat correctness, not majority correctness |
| majority_correct | 五次有效原正确性至少三次正确 | At least three correct outcomes among five valid repetitions |
| correctness_disagreement | 五次二元正确性不全相同 | Binary correctness differs across repeats |
| truncated_n | 字段指定对象的实际计数 | Observed count of the object named by the field |
| extraction_failed_n | 字段指定对象的实际计数 | Observed count of the object named by the field |
| final_models | 按重复或调用顺序的分号分隔原值 | Semicolon-separated original values in repeat or call order |
| call_counts | 按重复或调用顺序的分号分隔原值 | Semicolon-separated original values in repeat or call order |
| energy_sensitivity_exclude_question | 后续涉及该单元能耗比较需排除该题敏感性检查 | Future energy comparisons involving this cell need a question-exclusion sensitivity check |
| summary_rule | 五次算术均值、样本SD、多数至少3/5 | Five-repeat arithmetic mean, sample SD, majority at least 3/5 |
| gpu_trapezoid_j_n_valid | 该前缀指标的有限有效重复数 | Number of finite valid repeats for the prefixed metric |
| gpu_trapezoid_j_mean | 该前缀指标的有效重复算术均值，单位同前缀 | Arithmetic mean of valid repeats; same unit as the prefixed metric |
| gpu_trapezoid_j_sd | 有效重复样本标准差，分母n−1；n<2为NA | Sample SD of valid repeats, denominator n−1; NA when n<2 |
| gpu_trapezoid_j_min | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| gpu_trapezoid_j_max | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| gpu_trapezoid_j_range | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| gpu_left_j_n_valid | 该前缀指标的有限有效重复数 | Number of finite valid repeats for the prefixed metric |
| gpu_left_j_mean | 该前缀指标的有效重复算术均值，单位同前缀 | Arithmetic mean of valid repeats; same unit as the prefixed metric |
| gpu_left_j_sd | 有效重复样本标准差，分母n−1；n<2为NA | Sample SD of valid repeats, denominator n−1; NA when n<2 |
| gpu_left_j_min | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| gpu_left_j_max | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| gpu_left_j_range | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| cpu_j_n_valid | 该前缀指标的有限有效重复数 | Number of finite valid repeats for the prefixed metric |
| cpu_j_mean | 该前缀指标的有效重复算术均值，单位同前缀 | Arithmetic mean of valid repeats; same unit as the prefixed metric |
| cpu_j_sd | 有效重复样本标准差，分母n−1；n<2为NA | Sample SD of valid repeats, denominator n−1; NA when n<2 |
| cpu_j_min | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| cpu_j_max | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| cpu_j_range | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| latency_ms_n_valid | 该前缀指标的有限有效重复数 | Number of finite valid repeats for the prefixed metric |
| latency_ms_mean | 该前缀指标的有效重复算术均值，单位同前缀 | Arithmetic mean of valid repeats; same unit as the prefixed metric |
| latency_ms_sd | 有效重复样本标准差，分母n−1；n<2为NA | Sample SD of valid repeats, denominator n−1; NA when n<2 |
| latency_ms_min | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| latency_ms_max | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| latency_ms_range | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| routing_latency_s_n_valid | 该前缀指标的有限有效重复数 | Number of finite valid repeats for the prefixed metric |
| routing_latency_s_mean | 该前缀指标的有效重复算术均值，单位同前缀 | Arithmetic mean of valid repeats; same unit as the prefixed metric |
| routing_latency_s_sd | 有效重复样本标准差，分母n−1；n<2为NA | Sample SD of valid repeats, denominator n−1; NA when n<2 |
| routing_latency_s_min | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| routing_latency_s_max | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| routing_latency_s_range | 有效重复最小值／最大值／max−min，单位同前缀 | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |

## run_reconciliation.csv

| Field | 中文定义 | English definition |
|---|---|---|
| run_id | 原运行标识 | Original run identifier |
| kind | 运行类型run/idle，或来源格式csv/json | Run kind run/idle, or source format csv/json |
| benchmark | 基准名称 | Benchmark name |
| strategy | manifest 策略名称 | Manifest strategy name |
| repetition | 原重复编号 1–5 | Original repetition identifier 1–5 |
| manifest_status | manifest原运行状态done，不等于科学验证通过 | Original manifest run status done, not scientific validation |
| manifest_exit_code | 原进程退出码 | Original process exit code |
| process_start_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| process_end_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| process_duration_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| sampling_start_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| sampling_end_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| sampling_duration_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| task_first_query_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| task_last_query_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| n_queries | 字段指定对象的实际计数 | Observed count of the object named by the field |
| n_calls | 字段指定对象的实际计数 | Observed count of the object named by the field |
| raw_energy_samples | 采样数据记录数；raw为原始，derived为初始化处理后 | Sample-record count; raw before and derived after initialization handling |
| derived_energy_samples | 采样数据记录数；raw为原始，derived为初始化处理后 | Sample-record count; raw before and derived after initialization handling |
| initial_duplicate_removed | 字段所述处理／核对／有效性／原记录标志；非整体科学有效性 | Named handling/check/validity/recorded flag; not overall scientific validity |
| initial_interval_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| initial_cpu_increment_diagnostic_j | J；sample/clipped为累计计数器或积分贡献，minus为显式差值 | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| excluded_cpu_initialization_j | 同 Time 首两计数器差，被排除于派生窗口；真实初段为0 | Equal-Time initial counter difference excluded from derived window; zero for genuine initial intervals |
| covered_query_duration_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| gap_duration_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| pre_query_duration_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| post_query_duration_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| idle_duration_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| missing_query_start_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| missing_query_end_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| source_energy_path | 相对项目根目录的来源路径 | Source path relative to the project root |
| source_energy_sha256 | 对应原文件的 SHA-256 字节哈希 | SHA-256 byte hash of the corresponding source file |
| source_summary_path | 相对项目根目录的来源路径 | Source path relative to the project root |
| source_summary_sha256 | 对应原文件的 SHA-256 字节哈希 | SHA-256 byte hash of the corresponding source file |
| gpu_trapezoid_covered_queries_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_gaps_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_pre_query_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_post_query_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_idle_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_window_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_reconciliation_error_j | 组成项之和减同方法同窗口总量，单位见后缀 | Component sum minus same-method/same-window total; unit given by suffix |
| gpu_trapezoid_tolerance_j | 1e-6 + 1e-10×|总量|，单位J；非测量不确定度 | 1e-6 + 1e-10 times absolute total, J; not measurement uncertainty |
| gpu_trapezoid_reconciliation_pass | 数值对账是否满足绝对＋相对容差 | Whether numerical reconciliation meets absolute-plus-relative tolerance |
| gpu_left_covered_queries_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_gaps_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_pre_query_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_post_query_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_idle_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_window_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_reconciliation_error_j | 组成项之和减同方法同窗口总量，单位见后缀 | Component sum minus same-method/same-window total; unit given by suffix |
| gpu_left_tolerance_j | 1e-6 + 1e-10×|总量|，单位J；非测量不确定度 | 1e-6 + 1e-10 times absolute total, J; not measurement uncertainty |
| gpu_left_reconciliation_pass | 数值对账是否满足绝对＋相对容差 | Whether numerical reconciliation meets absolute-plus-relative tolerance |
| cpu_covered_queries_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_gaps_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_pre_query_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_post_query_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_idle_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_window_j | 所标方法在覆盖query／空隙／首前／末后／idle／整个采样窗口的能量，J | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_reconciliation_error_j | 组成项之和减同方法同窗口总量，单位见后缀 | Component sum minus same-method/same-window total; unit given by suffix |
| cpu_tolerance_j | 1e-6 + 1e-10×|总量|，单位J；非测量不确定度 | 1e-6 + 1e-10 times absolute total, J; not measurement uncertainty |
| cpu_reconciliation_pass | 数值对账是否满足绝对＋相对容差 | Whether numerical reconciliation meets absolute-plus-relative tolerance |
| duration_reconciliation_error_ms | 组成项之和减同方法同窗口总量，单位见后缀 | Component sum minus same-method/same-window total; unit given by suffix |
| legacy_delta_gpu_j | 历史方法或历史summary对照；差值为字段所示左项减右项，J或pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| historical_summary_gpu_j | 历史方法或历史summary对照；差值为字段所示左项减右项，J或pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| legacy_gpu_minus_summary_j | 历史方法或历史summary对照；差值为字段所示左项减右项，J或pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| legacy_cpu_endpoint_j | 历史方法或历史summary对照；差值为字段所示左项减右项，J或pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| historical_summary_cpu_j | 历史方法或历史summary对照；差值为字段所示左项减右项，J或pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| legacy_cpu_minus_summary_j | 历史方法或历史summary对照；差值为字段所示左项减右项，J或pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| historical_energibridge_summary_cpu_j | 历史方法或历史summary对照；差值为字段所示左项减右项，J或pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| cpu_legacy_minus_derived_and_initialization_j | 历史方法或历史summary对照；差值为字段所示左项减右项，J或pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| gpu_trapezoid_minus_legacy_delta_j | 历史方法或历史summary对照；差值为字段所示左项减右项，J或pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| gpu_trapezoid_vs_legacy_delta_pct | 历史方法或历史summary对照；差值为字段所示左项减右项，J或pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| gpu_left_minus_trapezoid_j | J；sample/clipped为累计计数器或积分贡献，minus为显式差值 | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| gpu_left_vs_trapezoid_pct | 百分数；方法差为100×(left−trapezoid)/trapezoid；利用率为原样本等权均值 | Percent; method difference is 100×(left−trapezoid)/trapezoid; utilization uses equal-weight original samples |
| input_problem_count | 字段指定对象的实际计数 | Observed count of the object named by the field |

## idle_summary.csv

| Field | 中文定义 | English definition |
|---|---|---|
| run_id | 原运行标识 | Original run identifier |
| repetition | 原重复编号 1–5 | Original repetition identifier 1–5 |
| sampling_start_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| sampling_end_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| effective_duration_s | 秒，定义由字段对应时间窗口指定 | Seconds, for the time interval named in the field |
| gpu_trapezoid_j | 完整窗口 GPU 线性梯形能耗，J；缺覆盖为 NA | Complete-window GPU linear-trapezoid energy, J; NA if coverage is incomplete |
| gpu_left_j | 完整窗口 GPU 原区间左保持能耗，J；缺覆盖为 NA | Complete-window GPU original-interval left-hold energy, J; NA if incomplete |
| cpu_j | 完整窗口 CPU 边界计数器差，J；缺覆盖或跨异常为 NA | Complete-window CPU boundary-counter difference, J; NA for incomplete coverage or anomalies |
| mean_gpu_trapezoid_w | 相应能耗除以有效秒数，W | Corresponding energy divided by effective seconds, W |
| mean_gpu_left_w | 相应能耗除以有效秒数，W | Corresponding energy divided by effective seconds, W |
| mean_cpu_w | 相应能耗除以有效秒数，W | Corresponding energy divided by effective seconds, W |
| raw_samples | 采样数据记录数；raw为原始，derived为初始化处理后 | Sample-record count; raw before and derived after initialization handling |
| derived_samples | 采样数据记录数；raw为原始，derived为初始化处理后 | Sample-record count; raw before and derived after initialization handling |
| initial_duplicate_removed | 字段所述处理／核对／有效性／原记录标志；非整体科学有效性 | Named handling/check/validity/recorded flag; not overall scientific validity |
| excluded_cpu_initialization_j | 同 Time 首两计数器差，被排除于派生窗口；真实初段为0 | Equal-Time initial counter difference excluded from derived window; zero for genuine initial intervals |
| initial_cpu_increment_diagnostic_j | J；sample/clipped为累计计数器或积分贡献，minus为显式差值 | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| energy_scope | 目标窗口的gross能耗；仍须读取coverage字段 | Gross energy for the intended window; coverage fields still apply |
| source_energy_path | 相对项目根目录的来源路径 | Source path relative to the project root |
| source_energy_sha256 | 对应原文件的 SHA-256 字节哈希 | SHA-256 byte hash of the corresponding source file |
| resident_ok_before_recorded | 字段所述处理／核对／有效性／原记录标志；非整体科学有效性 | Named handling/check/validity/recorded flag; not overall scientific validity |
| resident_ok_after_recorded | 字段所述处理／核对／有效性／原记录标志；非整体科学有效性 | Named handling/check/validity/recorded flag; not overall scientific validity |

## run_resources.csv

| Field | 中文定义 | English definition |
|---|---|---|
| run_id | 原运行标识 | Original run identifier |
| kind | 运行类型run/idle，或来源格式csv/json | Run kind run/idle, or source format csv/json |
| benchmark | 基准名称 | Benchmark name |
| strategy | manifest 策略名称 | Manifest strategy name |
| repetition | 原重复编号 1–5 | Original repetition identifier 1–5 |
| resource_level | run：运行级，不是逐题测量 | run: run-level, not query-level measurement |
| source_energy_path | 相对项目根目录的来源路径 | Source path relative to the project root |
| source_energy_sha256 | 对应原文件的 SHA-256 字节哈希 | SHA-256 byte hash of the corresponding source file |
| raw_energy_samples | 采样数据记录数；raw为原始，derived为初始化处理后 | Sample-record count; raw before and derived after initialization handling |
| mean_gpu_utilization_pct | 百分数；方法差为100×(left−trapezoid)/trapezoid；利用率为原样本等权均值 | Percent; method difference is 100×(left−trapezoid)/trapezoid; utilization uses equal-weight original samples |
| mean_cpu_utilization_pct | 百分数；方法差为100×(left−trapezoid)/trapezoid；利用率为原样本等权均值 | Percent; method difference is 100×(left−trapezoid)/trapezoid; utilization uses equal-weight original samples |
| peak_single_gpu_memory_mib | 跨设备和采样的最大单卡内存，MiB | Maximum single-card memory across devices and samples, MiB |
| peak_system_memory_bytes | 字节数；内存为bytes，文件为原文件大小 | Bytes; memory in bytes or original file size |
| aggregation | 资源指标的原样本等权／单卡峰值约定 | Original equal-sample weighting / single-device peak resource convention |

## initialization_records.csv

| Field | 中文定义 | English definition |
|---|---|---|
| run_id | 原运行标识 | Original run identifier |
| kind | 运行类型run/idle，或来源格式csv/json | Run kind run/idle, or source format csv/json |
| energy_source | 相对项目根目录的来源路径 | Source path relative to the project root |
| energy_sha256 | 对应原文件的 SHA-256 字节哈希 | SHA-256 byte hash of the corresponding source file |
| first_time_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| second_time_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| initial_interval_ms | 毫秒；时间戳为Unix墙钟，duration/interval/bracket/missing为时长 | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| first_cpu_j | J；sample/clipped为累计计数器或积分贡献，minus为显式差值 | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| second_cpu_j | J；sample/clipped为累计计数器或积分贡献，minus为显式差值 | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| initial_cpu_increment_j | 原前两条 CPU 差，诊断值；不得重复加减 | Original first-two CPU difference, diagnostic only; do not add/subtract twice |
| excluded_cpu_initialization_j | 同 Time 首两计数器差，被排除于派生窗口；真实初段为0 | Equal-Time initial counter difference excluded from derived window; zero for genuine initial intervals |
| initial_duplicate_removed | 字段所述处理／核对／有效性／原记录标志；非整体科学有效性 | Named handling/check/validity/recorded flag; not overall scientific validity |
| removed_source_record_index | 原 CSV 数据记录序号；以1起，不等于多行CSV物理行 | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| retained_source_record_index | 原 CSV 数据记录序号；以1起，不等于多行CSV物理行 | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |

## source_manifest.csv

| Field | 中文定义 | English definition |
|---|---|---|
| path | 相对项目根目录的来源路径 | Source path relative to the project root |
| sha256 | 对应原文件的 SHA-256 字节哈希 | SHA-256 byte hash of the corresponding source file |
| bytes | 字节数；内存为bytes，文件为原文件大小 | Bytes; memory in bytes or original file size |
| records | 字段指定对象的实际计数 | Observed count of the object named by the field |
| format | 运行类型run/idle，或来源格式csv/json | Run kind run/idle, or source format csv/json |

## 其他审计表 / Other audit tables

中文：initialization_samples.csv 保留每次原前两条完整采样字段；energy 原字段名带单位者按原单位，Time/Delta 为 ms，CPU_ENERGY 为累计 J，GPU*_POWER 为 mW。example_queries 沿用 query_metrics 字典并增加 case_type；example_calls 保留原 calls 字段，响应可多行，来源以记录号定位；example_segments 的 sample 左右值、clipped 边界值和逐段 J 对应 methods.md 公式。offline_tests 每行有双语描述、expected/actual、误差和容差。processing_issues 为空时仅说明没有新增计算异常；历史局限见报告。

English: initialization_samples.csv retains each run's complete first two raw samples; unit-bearing energy headers retain their units, with Time/Delta in ms, CPU_ENERGY cumulative J and GPU*_POWER in mW. example_queries uses the query_metrics dictionary plus case_type. example_calls retains original call fields, including multiline responses, located by source record index. example_segments sample endpoints, clipped boundaries and segment J follow methods.md formulas. Each offline_tests row contains bilingual descriptions, expected/actual values, errors and tolerances. An empty processing_issues table means no newly observed calculation anomaly, not absence of historical limitations.

