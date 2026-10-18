# Descriptive summaries only. No tests of hypotheses, intervals or effect sizes.
# Approved input tables are copied before mutation; every output must be new.
make_tables <- function(q, s, r, idle, resources, out) {
  if (!requireNamespace("data.table", quietly = TRUE)) stop("data.table is required")
  out <- normalizePath(out, winslash = "/", mustWork = TRUE)
  q <- data.table::copy(q)
  s <- data.table::copy(s)
  r <- data.table::copy(r)
  idle <- data.table::copy(idle)
  resources <- data.table::copy(resources)
  flags <- function(x) {
    z <- tolower(as.character(x))
    if (anyNA(z) || any(!z %in% c("true", "false", "1", "0"))) {
      stop("Unexpected or missing binary flag")
    }
    z %in% c("true", "1")
  }
  describe <- function(x) {
    if (any(is.nan(x) | is.infinite(x))) stop("Non-finite descriptive input")
    z <- x[!is.na(x)]
    n <- length(z)
    list(n = n, n_missing = length(x) - n,
         mean = if (n) mean(z) else NA_real_,
         median = if (n) stats::median(z) else NA_real_,
         sd = if (n > 1L) stats::sd(z) else NA_real_,
         variance = if (n > 1L) stats::var(z) else NA_real_,
         min = if (n) min(z) else NA_real_,
         max = if (n) max(z) else NA_real_)
  }
  strict_sum <- function(x) {
    if (any(!is.finite(x))) stop("Missing/non-finite count or token value")
    sum(x)
  }
  metric_units <- c(gpu_trapezoid_j = "J/query", cpu_j = "J/query", latency_s = "s/query")
  q[, correct_flag := flags(correct_numeric)]
  q[, truncated_flag := flags(truncated)]
  q[, extraction_failed_flag := flags(extraction_failed)]
  q[, error_flag := !is.na(error) & nzchar(trimws(as.character(error)))]
  q[, latency_s_descriptive := latency_ms / 1000]
  s[, majority_flag := flags(majority_correct)]
  s[, disagreement_flag := flags(correctness_disagreement)]
  s[, latency_s_descriptive := latency_ms_mean / 1000]

  # Main unit: one question's arithmetic mean over its valid repeated runs.
  source_metrics <- c(gpu_trapezoid_j_mean = "gpu_trapezoid_j",
                      cpu_j_mean = "cpu_j", latency_s_descriptive = "latency_s")
  continuous_summary <- data.table::rbindlist(lapply(names(source_metrics), function(col) {
    metric_name <- unname(source_metrics[[col]])
    d <- s[, describe(get(col)), by = .(benchmark, strategy)]
    d[, `:=`(metric = metric_name, unit = metric_units[[metric_name]],
             level = "question_mean_across_repetitions", denominator = "questions",
             sd_definition = "sample_sd_between_question_means_not_standard_error",
             source_table = "question_summary.csv")]
    d
  }))

  # Separately show each run, including the 199-question complete-energy denominator.
  query_metrics <- c(gpu_trapezoid_j = "gpu_trapezoid_j", cpu_j = "cpu_j",
                     latency_s_descriptive = "latency_s")
  run_means <- data.table::rbindlist(lapply(names(query_metrics), function(col) {
    metric_name <- unname(query_metrics[[col]])
    d <- q[, c(list(n_total = .N), describe(get(col))),
           by = .(benchmark, strategy, repetition, run_id)]
    data.table::setnames(d, "n", "n_valid")
    d[, `:=`(metric = metric_name, unit = metric_units[[metric_name]],
             level = "run_mean_of_complete_query_metrics",
             denominator = "queries_with_complete_metric_in_this_run",
             coverage_note = ifelse(n_valid == n_total, "all_query_values_available",
                                    "approved_missing_tail_energy_omitted_from_mean_not_replaced_by_partial"),
             source_table = "query_metrics.csv")]
    d
  }))
  run_meta <- r[kind == "run", .(run_id, process_start_ms, process_end_ms)]
  run_means <- merge(run_means, run_meta, by = "run_id", all.x = TRUE, sort = FALSE)
  run_variability <- run_means[, c(describe(mean), list(
    n_runs = .N, query_denominator_min = min(n_valid), query_denominator_max = max(n_valid),
    total_valid_query_values = sum(n_valid))), by = .(benchmark, strategy, metric, unit)]
  run_variability[, `:=`(level = "between_five_run_means", denominator = "runs",
                         weighting = "each_run_mean_weighted_equally",
                         sd_definition = "sample_sd_between_run_means_not_standard_error",
                         source_table = "run_means.csv")]

  accuracy_summary <- s[, .(
    n_questions = .N, majority_correct_count = sum(majority_flag),
    majority_accuracy = mean(majority_flag), mean_repeat_accuracy = mean(mean_correct),
    correct_repeat_count = sum(correct_sum), total_correctness_observations = sum(correct_n_valid),
    disagreement_questions = sum(disagreement_flag), disagreement_proportion = mean(disagreement_flag),
    repetitions_min = min(correct_n_valid), repetitions_max = max(correct_n_valid)
  ), by = .(benchmark, strategy)]
  accuracy_summary[, `:=`(level = "question_correctness_across_five_repetitions",
                          majority_denominator = "n_questions",
                          mean_repeat_denominator = "five_correctness_values_per_question_then_equal_question_mean",
                          majority_rule = "at_least_three_of_five_binary_correctness_values_not_answer_text_vote",
                          unit = "proportion", source_table = "question_summary.csv")]
  run_accuracy <- q[, .(n_queries = .N, n_correct = sum(correct_flag), accuracy = mean(correct_flag)),
                    by = .(benchmark, strategy, repetition, run_id)]
  run_accuracy[, `:=`(level = "run", denominator = "all_queries_in_run",
                      unit = "proportion", source_table = "query_metrics.csv")]

  # Keep zero selections visible; denominator is all 1,000 query-repeat records per cell.
  model_levels <- c("qwen3.5:4b", "qwen3.5:9b", "qwen3.5:27b")
  if (any(!q$final_model %in% model_levels)) stop("Unexpected final model")
  routing_summary <- q[, {
    counts <- tabulate(match(final_model, model_levels), nbins = length(model_levels))
    list(final_model = model_levels, n_selected = counts, n_queries = .N,
         selection_proportion = counts / .N)
  }, by = .(benchmark, strategy)]
  routing_summary[, `:=`(level = "query_repetition_final_answer_model", unit = "proportion",
                         denominator = "all_query_repetition_records_per_benchmark_strategy",
                         source_table = "query_metrics.csv")]

  auxiliary_summary <- q[, {
    route <- describe(routing_latency_s)
    embed_calls <- strict_sum(embedding_call_count)
    embed_available <- strict_sum(embedding_prompt_tokens_n_available)
    list(
      n_query_records = .N, n_runs = data.table::uniqueN(run_id),
      total_calls = strict_sum(call_count), mean_calls_per_query = mean(call_count),
      generate_calls = strict_sum(generate_call_count_observed),
      mean_generate_calls_per_query = mean(generate_call_count_observed),
      embedding_calls = embed_calls, mean_embedding_calls_per_query = mean(embedding_call_count),
      prompt_tokens_generate_total = strict_sum(prompt_tokens_total),
      prompt_tokens_generate_mean_per_query = mean(prompt_tokens_total),
      generated_tokens_total = strict_sum(completion_tokens_total),
      generated_tokens_mean_per_query = mean(completion_tokens_total),
      generated_tokens_median_per_query = stats::median(completion_tokens_total),
      generated_tokens_sd_per_query = stats::sd(completion_tokens_total),
      generated_tokens_min_per_query = min(completion_tokens_total),
      generated_tokens_max_per_query = max(completion_tokens_total),
      embedding_tokens_recorded_total = strict_sum(embedding_prompt_tokens),
      embedding_token_calls_available = embed_available,
      embedding_token_calls_missing = embed_calls - embed_available,
      embedding_tokens_mean_per_recorded_call = if (embed_available) sum(embedding_prompt_tokens) / embed_available else NA_real_,
      embedding_token_status = if (!embed_calls) "not_applicable_no_embedding_calls" else if (embed_available == embed_calls) "all_embedding_calls_recorded" else "incomplete_embedding_token_records",
      routing_latency_s_mean = route$mean, routing_latency_s_median = route$median,
      routing_latency_s_sd = route$sd, routing_latency_s_min = route$min, routing_latency_s_max = route$max
    )
  }, by = .(benchmark, strategy)]
  auxiliary_summary[, `:=`(level = "query_repetition", denominator = "n_query_records_unless_per_recorded_embedding_call",
                           token_scope = "generate_token_totals_exclude_embedding_embedding_tokens_separate",
                           routing_latency_definition = "end_to_end_minus_final_generate_includes_prior_generate_embedding_and_other_overhead",
                           routing_latency_unit = "s/query", call_unit = "calls", token_unit = "tokens",
                           source_table = "query_metrics.csv")]

  quality_summary <- q[, .(
    n_queries = .N, truncated_count = sum(truncated_flag), truncated_rate = mean(truncated_flag),
    extraction_failed_count = sum(extraction_failed_flag), extraction_failed_rate = mean(extraction_failed_flag),
    truncated_correct_count = sum(truncated_flag & correct_flag),
    truncated_correct_rate_all_queries = mean(truncated_flag & correct_flag),
    correctness_among_truncated = if (sum(truncated_flag)) sum(truncated_flag & correct_flag) / sum(truncated_flag) else NA_real_,
    error_count = sum(error_flag), error_rate = mean(error_flag)
  ), by = .(benchmark, strategy)]
  quality_summary[, `:=`(level = "query_repetition_final_answer", denominator = "all_queries_except_correctness_among_truncated",
                         truncated_correctness_denominator = "truncated_count", unit = "proportion",
                         scope = "saved_final_query_flags_not_all_intermediate_calls", source_table = "query_metrics.csv")]

  # Run-level resources stay at that level and never get duplicated into query rows.
  resources[, peak_system_memory_gib := peak_system_memory_bytes / (2^30)]
  resources[, `:=`(system_memory_conversion = "GiB=bytes/2^30",
                   gpu_memory_definition = "maximum_single_card_memory_not_sum_of_two_cards",
                   utilization_definition = "historical_equal_weight_raw_samples_and_devices",
                   source_table = "run_resources.csv")]
  resource_units <- c(mean_gpu_utilization_pct = "%", mean_cpu_utilization_pct = "%",
                      peak_single_gpu_memory_mib = "MiB/single_GPU", peak_system_memory_gib = "GiB")
  resources_summary <- data.table::rbindlist(lapply(names(resource_units), function(col) {
    d <- resources[, describe(get(col)), by = .(kind, benchmark, strategy)]
    d[, `:=`(metric = col, unit = resource_units[[col]], level = "between_run_resource_summaries",
             denominator = "runs_not_queries", source_table = "run_resources.csv")]
    d
  }))

  idle_runs <- data.table::copy(idle)
  idle_runs[, `:=`(level = "idle_run_sampling_window", denominator = "effective_duration_s_for_mean_power",
                   energy_unit = "J", power_unit = "W", time_unit = "s",
                   baseline_use = "gross_descriptive_only_no_net_subtraction", source_table = "idle_summary.csv")]
  idle_units <- c(mean_gpu_trapezoid_w = "W", mean_gpu_left_w = "W", mean_cpu_w = "W",
                  gpu_trapezoid_j = "J", gpu_left_j = "J", cpu_j = "J", effective_duration_s = "s")
  idle_variability <- data.table::rbindlist(lapply(names(idle_units), function(col) {
    d <- data.table::as.data.table(describe(idle[[col]]))
    d[, `:=`(metric = col, unit = idle_units[[col]], level = "between_five_idle_runs",
             denominator = "idle_runs", source_table = "idle_summary.csv")]
    d
  }))

  method_sensitivity_question <- s[, .(
    benchmark, strategy, query_id,
    gpu_trapezoid_j_mean, gpu_left_j_mean,
    n_valid_trapezoid = gpu_trapezoid_j_n_valid, n_valid_left = gpu_left_j_n_valid,
    energy_sensitivity_exclude_question,
    signed_difference_j = gpu_left_j_mean - gpu_trapezoid_j_mean,
    absolute_difference_j = abs(gpu_left_j_mean - gpu_trapezoid_j_mean),
    relative_difference_pct = ifelse(gpu_trapezoid_j_mean != 0,
                                    100 * (gpu_left_j_mean - gpu_trapezoid_j_mean) / gpu_trapezoid_j_mean, NA_real_)
  )]
  method_sensitivity_question[, `:=`(
    absolute_relative_difference_pct = abs(relative_difference_pct),
    level = "question_mean_across_valid_repetitions", unit_difference = "J/query", unit_relative = "%",
    direction = "left_hold_minus_trapezoid", denominator_relative = "trapezoid_question_mean",
    interpretation = "integration_method_sensitivity_not_sensor_accuracy_or_inferential_effect_size",
    source_table = "question_summary.csv")]
  method_sensitivity_summary <- method_sensitivity_question[, .(
    n_questions = .N,
    n_valid_relative = sum(!is.na(relative_difference_pct)),
    mean_signed_difference_j = mean(signed_difference_j),
    median_signed_difference_j = stats::median(signed_difference_j),
    sd_signed_difference_j = stats::sd(signed_difference_j),
    min_signed_difference_j = min(signed_difference_j), max_signed_difference_j = max(signed_difference_j),
    mean_absolute_difference_j = mean(absolute_difference_j),
    median_absolute_difference_j = stats::median(absolute_difference_j),
    max_absolute_difference_j = max(absolute_difference_j),
    mean_relative_difference_pct = mean(relative_difference_pct),
    median_relative_difference_pct = stats::median(relative_difference_pct),
    sd_relative_difference_pct = stats::sd(relative_difference_pct),
    min_relative_difference_pct = min(relative_difference_pct),
    q05_relative_difference_pct = as.numeric(stats::quantile(relative_difference_pct, 0.05, names = FALSE)),
    q25_relative_difference_pct = as.numeric(stats::quantile(relative_difference_pct, 0.25, names = FALSE)),
    q75_relative_difference_pct = as.numeric(stats::quantile(relative_difference_pct, 0.75, names = FALSE)),
    q95_relative_difference_pct = as.numeric(stats::quantile(relative_difference_pct, 0.95, names = FALSE)),
    max_relative_difference_pct = max(relative_difference_pct),
    mean_absolute_relative_difference_pct = mean(absolute_relative_difference_pct),
    max_absolute_relative_difference_pct = max(absolute_relative_difference_pct)
  ), by = .(benchmark, strategy)]
  method_sensitivity_summary[, `:=`(level = "distribution_of_question_level_method_differences",
                                    denominator = "question_means", difference_unit = "J/query", relative_unit = "%",
                                    quantile_definition = "empirical_type_7_distribution_quantiles_not_confidence_intervals",
                                    source_table = "method_sensitivity_question.csv")]

  tables <- list(continuous_summary = continuous_summary, run_means = run_means,
                 run_variability = run_variability, accuracy_summary = accuracy_summary,
                 run_accuracy = run_accuracy, routing_summary = routing_summary,
                 auxiliary_summary = auxiliary_summary, quality_summary = quality_summary,
                 run_resources = resources, resources_summary = resources_summary,
                 idle_runs = idle_runs, idle_variability = idle_variability,
                 method_sensitivity_question = method_sensitivity_question,
                 method_sensitivity_summary = method_sensitivity_summary)
  paths <- file.path(out, paste0(names(tables), ".csv"))
  if (any(file.exists(paths))) stop("Refusing to overwrite existing descriptive CSV output")
  for (i in seq_along(tables)) {
    d <- tables[[i]]
    order_cols <- intersect(c("benchmark", "strategy", "metric", "repetition", "run_id", "query_id", "final_model"), names(d))
    if (length(order_cols)) data.table::setorderv(d, order_cols, na.last = TRUE)
    data.table::fwrite(d, paths[[i]], na = "NA", quote = "auto", bom = FALSE)
  }
  tables
}
