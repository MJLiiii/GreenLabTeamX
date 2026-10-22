# Data dictionary

## General conventions

NA means unavailable, not zero. Original empty strings remain empty; True/False are original booleans and derived TRUE/FALSE are derived booleans. Query keys are benchmark, strategy, repetition and query_id; summary keys omit repetition. Retain run_id. All energy is gross, with separate GPU and CPU columns.

complete means full temporal coverage; approved_missing_tail_2ms is the approved uncovered tail; unexpected_missing_coverage is a new coverage gap; sensor_anomaly marks a sensor-segment anomaly; pass means that specific numerical check passed; fail/issues indicates a problem. No status means overall scientific validity.

## query_metrics.csv

| Field | English definition |
|---|---|
| run_id | Original run identifier |
| query_id | Original question ID; scoped by benchmark |
| benchmark | Benchmark name |
| split | Original data split |
| category | Original question category |
| router | Original routing strategy |
| final_model | Final generation model |
| models_called | Original generate-model sequence; excludes embed |
| num_generate_calls | Original generation call count |
| extracted_answer | Original extracted answer; not rescored |
| reference | Original reference answer |
| correct | Original correctness True/False |
| extraction_failed | Original extraction-failure flag |
| truncated | Original final-output truncation flag |
| started_at_ms | Original Unix wall-clock start, ms |
| ended_at_ms | Original Unix wall-clock end, ms |
| latency_s | Original monotonic latency in seconds |
| latency_ms | Original monotonic latency in milliseconds |
| routing_latency_s | Original end-to-end minus final generation seconds, including earlier calls and routing |
| prompt_tokens_total | Original prompt-token total across generate calls, excluding embed |
| completion_tokens_total | Original completion-token total across generate calls |
| error | Original error text; empty means no recorded error |
| strategy | Manifest strategy name |
| repetition | Original repetition identifier 1–5 |
| source_query_path | Source path relative to the project root |
| source_query_record_index | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| source_query_sha256 | SHA-256 byte hash of the corresponding source file |
| source_call_path | Source path relative to the project root |
| source_call_record_indices | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| source_call_sha256 | SHA-256 byte hash of the corresponding source file |
| source_energy_path | Source path relative to the project root |
| source_energy_sha256 | SHA-256 byte hash of the corresponding source file |
| source_manifest_record_index | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| source_manifest_sha256 | SHA-256 byte hash of the corresponding source file |
| settings_fingerprint | Historical settings fingerprint, not full provenance or a model digest |
| source_energy_first_record_index | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| source_energy_last_record_index | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| sampling_start_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| sampling_end_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| covered_start_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| covered_end_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| wall_duration_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| covered_duration_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| missing_start_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| missing_end_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| start_bracket_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| end_bracket_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| coverage_complete | Complete temporal coverage, not a sensor-accuracy guarantee |
| coverage_status | complete / approved_missing_tail_2ms / unexpected_missing_coverage; may append sensor_anomaly |
| gpu_trapezoid_j | Complete-window GPU linear-trapezoid energy, J; NA if coverage is incomplete |
| gpu_left_j | Complete-window GPU original-interval left-hold energy, J; NA if incomplete |
| cpu_j | Complete-window CPU boundary-counter difference, J; NA for incomplete coverage or anomalies |
| covered_gpu_trapezoid_j | Energy of the covered portion only, J; used in reconciliation even when complete energy is NA |
| covered_gpu_left_j | Energy of the covered portion only, J; used in reconciliation even when complete energy is NA |
| covered_cpu_j | Energy of the covered portion only, J; used in reconciliation even when complete energy is NA |
| gpu_left_minus_trapezoid_j | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| gpu_left_vs_trapezoid_pct | Percent; method difference is 100×(left−trapezoid)/trapezoid; utilization uses equal-weight original samples |
| correct_numeric | Original correctness encoded as 1/0 |
| call_count | Observed count of the object named by the field |
| generate_call_count_observed | Generate-call count recomputed from linked calls.csv records |
| embedding_call_count | Observed count of the object named by the field |
| embedding_prompt_tokens | Original token counts or availability counts for the named call kind; missing does not mean zero |
| embedding_prompt_tokens_n_available | Original token counts or availability counts for the named call kind; missing does not mean zero |
| generate_tokens_link_verified | Original token counts or availability counts for the named call kind; missing does not mean zero |
| call_query_link_verified | Named handling/check/validity/recorded flag; not overall scientific validity |
| all_calls_inside_query | Named handling/check/validity/recorded flag; not overall scientific validity |
| call_models_all | Semicolon-separated original values in repeat or call order |
| call_latency_sum_s | Seconds, for the time interval named in the field |
| query_minus_call_latency_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| gpu_method | Time-based linear trapezoid of summed two-GPU power |
| gpu_sensitivity_method | Original sampling-interval left-power hold |
| cpu_method | Time-based linear counter boundary difference |
| energy_scope | Gross energy for the intended window; coverage fields still apply |
| energy_sensitivity_exclude_question | Future energy comparisons involving this cell need a question-exclusion sensitivity check |
| initialization_removed_from_view | Named handling/check/validity/recorded flag; not overall scientific validity |

## question_summary.csv

| Field | English definition |
|---|---|
| benchmark | Benchmark name |
| strategy | Manifest strategy name |
| query_id | Original question ID; scoped by benchmark |
| n_repetitions | Observed count of the object named by the field |
| repetitions | Semicolon-separated original values in repeat or call order |
| run_ids | Semicolon-separated original values in repeat or call order |
| correct_by_repetition | Original 0/1 correctness in repetitions order |
| correct_n_valid | Number of finite valid repeats for the prefixed metric |
| correct_sum | Observed count of the object named by the field |
| mean_correct | Mean repeat correctness, not majority correctness |
| majority_correct | At least three correct outcomes among five valid repetitions |
| correctness_disagreement | Binary correctness differs across repeats |
| truncated_n | Observed count of the object named by the field |
| extraction_failed_n | Observed count of the object named by the field |
| final_models | Semicolon-separated original values in repeat or call order |
| call_counts | Semicolon-separated original values in repeat or call order |
| energy_sensitivity_exclude_question | Future energy comparisons involving this cell need a question-exclusion sensitivity check |
| summary_rule | Five-repeat arithmetic mean, sample SD, majority at least 3/5 |
| gpu_trapezoid_j_n_valid | Number of finite valid repeats for the prefixed metric |
| gpu_trapezoid_j_mean | Arithmetic mean of valid repeats; same unit as the prefixed metric |
| gpu_trapezoid_j_sd | Sample SD of valid repeats, denominator n−1; NA when n<2 |
| gpu_trapezoid_j_min | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| gpu_trapezoid_j_max | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| gpu_trapezoid_j_range | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| gpu_left_j_n_valid | Number of finite valid repeats for the prefixed metric |
| gpu_left_j_mean | Arithmetic mean of valid repeats; same unit as the prefixed metric |
| gpu_left_j_sd | Sample SD of valid repeats, denominator n−1; NA when n<2 |
| gpu_left_j_min | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| gpu_left_j_max | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| gpu_left_j_range | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| cpu_j_n_valid | Number of finite valid repeats for the prefixed metric |
| cpu_j_mean | Arithmetic mean of valid repeats; same unit as the prefixed metric |
| cpu_j_sd | Sample SD of valid repeats, denominator n−1; NA when n<2 |
| cpu_j_min | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| cpu_j_max | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| cpu_j_range | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| latency_ms_n_valid | Number of finite valid repeats for the prefixed metric |
| latency_ms_mean | Arithmetic mean of valid repeats; same unit as the prefixed metric |
| latency_ms_sd | Sample SD of valid repeats, denominator n−1; NA when n<2 |
| latency_ms_min | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| latency_ms_max | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| latency_ms_range | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| routing_latency_s_n_valid | Number of finite valid repeats for the prefixed metric |
| routing_latency_s_mean | Arithmetic mean of valid repeats; same unit as the prefixed metric |
| routing_latency_s_sd | Sample SD of valid repeats, denominator n−1; NA when n<2 |
| routing_latency_s_min | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| routing_latency_s_max | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |
| routing_latency_s_range | Valid-repeat minimum / maximum / max−min, in the prefixed metric's unit |

## run_reconciliation.csv

| Field | English definition |
|---|---|
| run_id | Original run identifier |
| kind | Run kind run/idle, or source format csv/json |
| benchmark | Benchmark name |
| strategy | Manifest strategy name |
| repetition | Original repetition identifier 1–5 |
| manifest_status | Original manifest run status done, not scientific validation |
| manifest_exit_code | Original process exit code |
| process_start_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| process_end_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| process_duration_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| sampling_start_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| sampling_end_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| sampling_duration_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| task_first_query_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| task_last_query_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| n_queries | Observed count of the object named by the field |
| n_calls | Observed count of the object named by the field |
| raw_energy_samples | Sample-record count; raw before and derived after initialization handling |
| derived_energy_samples | Sample-record count; raw before and derived after initialization handling |
| initial_duplicate_removed | Named handling/check/validity/recorded flag; not overall scientific validity |
| initial_interval_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| initial_cpu_increment_diagnostic_j | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| excluded_cpu_initialization_j | Equal-Time initial counter difference excluded from derived window; zero for genuine initial intervals |
| covered_query_duration_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| gap_duration_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| pre_query_duration_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| post_query_duration_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| idle_duration_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| missing_query_start_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| missing_query_end_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| source_energy_path | Source path relative to the project root |
| source_energy_sha256 | SHA-256 byte hash of the corresponding source file |
| source_summary_path | Source path relative to the project root |
| source_summary_sha256 | SHA-256 byte hash of the corresponding source file |
| gpu_trapezoid_covered_queries_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_gaps_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_pre_query_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_post_query_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_idle_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_window_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_trapezoid_reconciliation_error_j | Component sum minus same-method/same-window total; unit given by suffix |
| gpu_trapezoid_tolerance_j | 1e-6 + 1e-10 times absolute total, J; not measurement uncertainty |
| gpu_trapezoid_reconciliation_pass | Whether numerical reconciliation meets absolute-plus-relative tolerance |
| gpu_left_covered_queries_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_gaps_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_pre_query_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_post_query_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_idle_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_window_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| gpu_left_reconciliation_error_j | Component sum minus same-method/same-window total; unit given by suffix |
| gpu_left_tolerance_j | 1e-6 + 1e-10 times absolute total, J; not measurement uncertainty |
| gpu_left_reconciliation_pass | Whether numerical reconciliation meets absolute-plus-relative tolerance |
| cpu_covered_queries_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_gaps_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_pre_query_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_post_query_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_idle_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_window_j | Named-method energy for covered queries / gaps / pre / post / idle / whole sampling window, J |
| cpu_reconciliation_error_j | Component sum minus same-method/same-window total; unit given by suffix |
| cpu_tolerance_j | 1e-6 + 1e-10 times absolute total, J; not measurement uncertainty |
| cpu_reconciliation_pass | Whether numerical reconciliation meets absolute-plus-relative tolerance |
| duration_reconciliation_error_ms | Component sum minus same-method/same-window total; unit given by suffix |
| legacy_delta_gpu_j | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| historical_summary_gpu_j | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| legacy_gpu_minus_summary_j | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| legacy_cpu_endpoint_j | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| historical_summary_cpu_j | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| legacy_cpu_minus_summary_j | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| historical_energibridge_summary_cpu_j | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| cpu_legacy_minus_derived_and_initialization_j | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| gpu_trapezoid_minus_legacy_delta_j | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| gpu_trapezoid_vs_legacy_delta_pct | Historical-method or summary comparison; differences are named left minus right, in J or percent |
| gpu_left_minus_trapezoid_j | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| gpu_left_vs_trapezoid_pct | Percent; method difference is 100×(left−trapezoid)/trapezoid; utilization uses equal-weight original samples |
| input_problem_count | Observed count of the object named by the field |

## idle_summary.csv

| Field | English definition |
|---|---|
| run_id | Original run identifier |
| repetition | Original repetition identifier 1–5 |
| sampling_start_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| sampling_end_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| effective_duration_s | Seconds, for the time interval named in the field |
| gpu_trapezoid_j | Complete-window GPU linear-trapezoid energy, J; NA if coverage is incomplete |
| gpu_left_j | Complete-window GPU original-interval left-hold energy, J; NA if incomplete |
| cpu_j | Complete-window CPU boundary-counter difference, J; NA for incomplete coverage or anomalies |
| mean_gpu_trapezoid_w | Corresponding energy divided by effective seconds, W |
| mean_gpu_left_w | Corresponding energy divided by effective seconds, W |
| mean_cpu_w | Corresponding energy divided by effective seconds, W |
| raw_samples | Sample-record count; raw before and derived after initialization handling |
| derived_samples | Sample-record count; raw before and derived after initialization handling |
| initial_duplicate_removed | Named handling/check/validity/recorded flag; not overall scientific validity |
| excluded_cpu_initialization_j | Equal-Time initial counter difference excluded from derived window; zero for genuine initial intervals |
| initial_cpu_increment_diagnostic_j | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| energy_scope | Gross energy for the intended window; coverage fields still apply |
| source_energy_path | Source path relative to the project root |
| source_energy_sha256 | SHA-256 byte hash of the corresponding source file |
| resident_ok_before_recorded | Named handling/check/validity/recorded flag; not overall scientific validity |
| resident_ok_after_recorded | Named handling/check/validity/recorded flag; not overall scientific validity |

## run_resources.csv

| Field | English definition |
|---|---|
| run_id | Original run identifier |
| kind | Run kind run/idle, or source format csv/json |
| benchmark | Benchmark name |
| strategy | Manifest strategy name |
| repetition | Original repetition identifier 1–5 |
| resource_level | run: run-level, not query-level measurement |
| source_energy_path | Source path relative to the project root |
| source_energy_sha256 | SHA-256 byte hash of the corresponding source file |
| raw_energy_samples | Sample-record count; raw before and derived after initialization handling |
| mean_gpu_utilization_pct | Percent; method difference is 100×(left−trapezoid)/trapezoid; utilization uses equal-weight original samples |
| mean_cpu_utilization_pct | Percent; method difference is 100×(left−trapezoid)/trapezoid; utilization uses equal-weight original samples |
| peak_single_gpu_memory_mib | Maximum single-card memory across devices and samples, MiB |
| peak_system_memory_bytes | Bytes; memory in bytes or original file size |
| aggregation | Original equal-sample weighting / single-device peak resource convention |

## initialization_records.csv

| Field | English definition |
|---|---|
| run_id | Original run identifier |
| kind | Run kind run/idle, or source format csv/json |
| energy_source | Source path relative to the project root |
| energy_sha256 | SHA-256 byte hash of the corresponding source file |
| first_time_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| second_time_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| initial_interval_ms | Milliseconds; timestamps are Unix wall clock, while duration/interval/bracket/missing fields are durations |
| first_cpu_j | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| second_cpu_j | J; sample/clipped fields are cumulative counters or contributions; minus denotes an explicit difference |
| initial_cpu_increment_j | Original first-two CPU difference, diagnostic only; do not add/subtract twice |
| excluded_cpu_initialization_j | Equal-Time initial counter difference excluded from derived window; zero for genuine initial intervals |
| initial_duplicate_removed | Named handling/check/validity/recorded flag; not overall scientific validity |
| removed_source_record_index | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |
| retained_source_record_index | Original CSV data-record indices, starting at 1; not physical lines for multiline CSV |

## source_manifest.csv

| Field | English definition |
|---|---|
| path | Source path relative to the project root |
| sha256 | SHA-256 byte hash of the corresponding source file |
| bytes | Bytes; memory in bytes or original file size |
| records | Observed count of the object named by the field |
| format | Run kind run/idle, or source format csv/json |

## Other audit tables

initialization_samples.csv retains each run's complete first two raw samples; unit-bearing energy headers retain their units, with Time/Delta in ms, CPU_ENERGY cumulative J and GPU*_POWER in mW. example_queries uses the query_metrics dictionary plus case_type. example_calls retains original call fields, including multiline responses, located by source record index. example_segments sample endpoints, clipped boundaries and segment J follow methods.md formulas. Each offline_tests row contains bilingual descriptions, expected/actual values, errors and tolerances. An empty processing_issues table means no newly observed calculation anomaly, not absence of historical limitations.

