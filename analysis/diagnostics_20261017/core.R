# Offline diagnostics only: no tests of hypotheses, inferential intervals or effects.
# All energy inputs are already-reviewed derived values; no raw integration occurs.

diag_assert <- function(ok, message) {
  if (!isTRUE(ok)) stop(message, call. = FALSE)
}

diag_metric_values <- function(tab, metric, summary = FALSE) {
  if (summary) {
    field <- if (metric == "latency_s") "latency_ms_mean" else paste0(metric, "_mean")
  } else field <- if (metric == "latency_s") "latency_ms" else metric
  value <- as.numeric(tab[[field]])
  if (metric == "latency_s") value <- value / 1000
  value
}

diag_pair <- function(tab, benchmark_name, strategy_a_name, strategy_b_name,
                      metric_name, excluded_query = NULL, summary = TRUE) {
  make_side <- function(strategy_name) {
    z <- data.table::copy(tab[benchmark == benchmark_name & strategy == strategy_name])
    if (!is.null(excluded_query)) z <- z[!as.character(query_id) %in% as.character(excluded_query)]
    z[, value := diag_metric_values(z, metric_name, summary)]
    if (summary) {
      diag_assert(!anyDuplicated(z$query_id), "Duplicate question key in pairing input")
      valid_field <- if (metric_name == "latency_s") "latency_ms_n_valid" else paste0(metric_name, "_n_valid")
      z <- z[, .(query_id = as.character(query_id), value, n_valid = as.integer(get(valid_field)))]
    } else {
      z <- z[, .(value = if (all(is.na(value))) NA_real_ else mean(value, na.rm = TRUE),
                 n_valid = sum(is.finite(value))), by = .(query_id = as.character(query_id))]
    }
    z
  }
  a <- make_side(strategy_a_name); b <- make_side(strategy_b_name)
  diag_assert(setequal(a$query_id, b$query_id), "Question sets differ in pairing input")
  data.table::setnames(a, c("value", "n_valid"), c("value_a", "n_valid_a"))
  data.table::setnames(b, c("value", "n_valid"), c("value_b", "n_valid_b"))
  paired <- merge(a, b, by = "query_id", sort = FALSE)
  diag_assert(all(is.finite(paired$value_a) & is.finite(paired$value_b)),
              "A paired question mean is missing or non-finite")
  paired[, difference := value_a - value_b]
  paired
}

diag_loo_question <- function(d) {
  n <- length(d)
  diag_assert(n >= 2L && all(is.finite(d)), "Invalid leave-one-question input")
  reference <- mean(d)
  estimate <- (sum(d) - d) / (n - 1L)
  data.table::data.table(reference_estimate = reference, estimate = estimate,
                         signed_change = estimate - reference,
                         absolute_change = abs(estimate - reference))
}

diag_acf <- function(x, max_lag = 10L) {
  # Preserve positions of missing measurements. Never compress an NA-containing
  # sequence, since doing so would create false adjacency across a missing query.
  finite <- is.finite(x)
  centered <- x - mean(x[finite])
  denominator <- sum(centered[finite]^2)
  data.table::rbindlist(lapply(seq_len(max_lag), function(k) {
    if (length(x) <= k) {
      return(data.table::data.table(lag = k, acf = NA_real_, valid_pairs = 0L,
                                   n_finite = sum(finite), n_positions = length(x)))
    }
    left <- seq_len(length(x) - k); right <- left + k
    keep <- finite[left] & finite[right]
    data.table::data.table(lag = k,
      acf = if (denominator > 0 && any(keep))
        sum(centered[left[keep]] * centered[right[keep]]) / denominator else NA_real_,
      valid_pairs = sum(keep), n_finite = sum(finite), n_positions = length(x))
  }))
}

diag_distribution <- function(x) {
  diag_assert(length(x) > 0L && all(is.finite(x)), "Non-finite paired difference")
  n <- length(x); mn <- mean(x); sdv <- stats::sd(x)
  quant <- stats::quantile(x, c(.01, .05, .25, .75, .95, .99), names = FALSE, type = 7)
  skew <- if (n >= 3L && sdv > 0)
    n / ((n - 1) * (n - 2)) * sum(((x - mn) / sdv)^3) else NA_real_
  data.table::data.table(n = n, mean_difference = mn, median_difference = stats::median(x),
    sd_difference = sdv, variance_difference = stats::var(x),
    minimum = min(x), q01 = quant[1L], q05 = quant[2L], q25 = quant[3L],
    q75 = quant[4L], q95 = quant[5L], q99 = quant[6L], maximum = max(x),
    skewness = skew, mean_absolute_difference = mean(abs(x)),
    skewness_definition = "adjusted_Fisher_Pearson", quantile_type = 7L)
}

diag_sensitivity <- function(paired, reference, specification_id, parent_id,
                             analysis_variant, scenario, excluded_side = "none",
                             excluded_run_id = "", excluded_query = "") {
  estimate <- mean(paired$difference)
  baseline <- mean(reference$difference)
  scale <- mean((abs(reference$value_a) + abs(reference$value_b)) / 2)
  cutoff <- max(1e-8, 0.01 * scale)
  relative_ok <- abs(baseline) > cutoff
  data.table::data.table(specification_id = specification_id,
    parent_comparison_id = parent_id, analysis_variant = analysis_variant,
    scenario = scenario, excluded_side = excluded_side, excluded_run_id = excluded_run_id,
    excluded_query_id = excluded_query, n_questions = nrow(paired),
    reference_n_questions = nrow(reference), n_valid_a_min = min(paired$n_valid_a),
    n_valid_a_max = max(paired$n_valid_a), n_valid_b_min = min(paired$n_valid_b),
    n_valid_b_max = max(paired$n_valid_b), estimate = estimate,
    reference_estimate = baseline, signed_change = estimate - baseline,
    absolute_change = abs(estimate - baseline),
    relative_change_pct = if (relative_ok) 100 * (estimate - baseline) / abs(baseline) else NA_real_,
    relative_change_status = if (relative_ok) "applicable" else "not_applicable_near_zero_reference",
    relative_reference_scale = scale, relative_reference_cutoff = cutoff,
    relative_formula = "100*(estimate-reference)/abs(reference);abs(reference)>max(1e-8,0.01*mean((abs(A)+abs(B))/2))")
}

compute_diagnostics <- function(q, s, r, plan, out = NULL) {
  q <- data.table::copy(q); s <- data.table::copy(s)
  r <- data.table::copy(r); plan <- data.table::copy(plan)
  q[, query_id := as.character(query_id)]; s[, query_id := as.character(query_id)]
  for (field in c("source_query_record_index", "started_at_ms", "ended_at_ms", "repetition")) {
    data.table::set(q, j = field, value = as.numeric(q[[field]]))
  }
  q[, category := ifelse(is.na(category), "", as.character(category))]
  primary <- plan[analysis_variant == "primary_method"]
  continuous <- primary[metric != "majority_correct"]
  accuracy <- primary[metric == "majority_correct"]
  diag_assert(nrow(continuous) == 40L && nrow(accuracy) == 14L, "Unexpected primary comparison counts")
  diag_assert(!anyDuplicated(plan$comparison_id), "Duplicate comparison IDs")
  diag_assert(nrow(q) == 10000L && nrow(s) == 2000L, "Unexpected approved input row counts")

  # Actual CSV record positions, not numeric or lexicographic question IDs.
  qo <- q[, .(n_orders = data.table::uniqueN(source_query_record_index),
              question_order = source_query_record_index[1L],
              n_categories = data.table::uniqueN(category), category = category[1L],
              observed_runs = data.table::uniqueN(run_id),
              source_query_paths = paste(sort(unique(source_query_path)), collapse = ";")),
          by = .(benchmark, query_id)]
  diag_assert(all(qo$n_orders == 1L & qo$n_categories == 1L & qo$observed_runs == 25L),
              "Query order or category is not identical across all benchmark runs")
  diag_assert(qo[, all(sort(question_order) == seq_len(.N)), by = benchmark][, all(V1)],
              "Source query record indices are not a complete 1:200 order")
  data.table::setorder(qo, benchmark, question_order)

  paired_list <- list(); summary_list <- list(); loo_list <- list(); pacf_list <- list()
  category_list <- list()
  for (i in seq_len(nrow(continuous))) {
    p <- continuous[i]
    d <- diag_pair(s, p$benchmark, p$strategy_a, p$strategy_b, p$metric)
    d <- merge(d, qo[benchmark == p$benchmark, .(query_id, question_order, category)], by = "query_id")
    d[, `:=`(comparison_id = p$comparison_id, benchmark = p$benchmark,
             strategy_a = p$strategy_a, strategy_b = p$strategy_b, metric = p$metric,
             unit = if (p$metric == "latency_s") "s/query" else "J/query")]
    # Retain all five-run source sets to connect an influential question to evidence.
    da <- s[benchmark == p$benchmark & strategy == p$strategy_a, .(query_id, run_ids_a = run_ids)]
    db <- s[benchmark == p$benchmark & strategy == p$strategy_b, .(query_id, run_ids_b = run_ids)]
    d <- merge(merge(d, da, by = "query_id"), db, by = "query_id")
    d[, `:=`(source_query_record_index = question_order,
      source_query_paths_a = vapply(strsplit(run_ids_a, ";", fixed = TRUE),
          function(ids) paste(paste0("results/main/", ids, "/queries.csv"), collapse = ";"), character(1)),
      source_query_paths_b = vapply(strsplit(run_ids_b, ";", fixed = TRUE),
          function(ids) paste(paste0("results/main/", ids, "/queries.csv"), collapse = ";"), character(1)))]
    data.table::setorder(d, question_order)
    paired_list[[i]] <- d
    l <- cbind(d[, .(comparison_id, benchmark, strategy_a, strategy_b, metric, query_id,
                     question_order, category, difference, run_ids_a, run_ids_b,
                     source_query_record_index, source_query_paths_a, source_query_paths_b)],
               diag_loo_question(d$difference))
    loo_list[[i]] <- l
    top <- which.max(l$absolute_change)
    z <- diag_distribution(d$difference)
    z[, `:=`(comparison_id = p$comparison_id, benchmark = p$benchmark,
              strategy_a = p$strategy_a, strategy_b = p$strategy_b, metric = p$metric,
              unit = if (p$metric == "latency_s") "s/query" else "J/query",
              max_abs_leave_one_question_change = l$absolute_change[top],
              influential_query_id = d$query_id[top], influential_question_order = d$question_order[top],
              influential_category = d$category[top], influential_difference = d$difference[top],
              leave_one_question_estimate_min = min(l$estimate),
              leave_one_question_estimate_max = max(l$estimate),
              leave_one_question_sign_changes = sum(sign(l$estimate) != sign(mean(d$difference))),
              source_query_paths_a = d$source_query_paths_a[top],
              source_query_paths_b = d$source_query_paths_b[top])]
    summary_list[[i]] <- z
    ac <- diag_acf(d$difference)
    ac[, `:=`(comparison_id = p$comparison_id, benchmark = p$benchmark,
              strategy_a = p$strategy_a, strategy_b = p$strategy_b, metric = p$metric,
              sequence = "identical_actual_source_query_record_order",
              interpretation = "descriptive_lag_association_not_independence_test")]
    pacf_list[[i]] <- ac
    if (p$benchmark == "mmlu_pro") {
      cz <- d[, diag_distribution(difference), by = category]
      cz[, `:=`(comparison_id = p$comparison_id, benchmark = p$benchmark,
                 strategy_a = p$strategy_a, strategy_b = p$strategy_b, metric = p$metric)]
      category_list[[length(category_list) + 1L]] <- cz
    }
  }
  paired <- data.table::rbindlist(paired_list)
  diagnostics_summary <- data.table::rbindlist(summary_list)
  leave_one_question <- data.table::rbindlist(loo_list)
  paired_difference_acf <- data.table::rbindlist(pacf_list)

  # Per-run repeated-measurement residuals retain the energy NA in its position.
  metrics <- c("gpu_trapezoid_j", "cpu_j", "latency_s")
  residual_list <- lapply(metrics, function(m) {
    z <- q[, .(run_id, query_id, benchmark, strategy, repetition, category,
      source_query_record_index, source_query_path, source_query_sha256,
      started_at_ms, ended_at_ms)]
    z[, `:=`(metric = m, value = diag_metric_values(q, m, FALSE))]
    sm <- s[, .(benchmark, strategy, query_id)]
    sm[, question_mean := diag_metric_values(s, m, TRUE)]
    z <- merge(z, sm, by = c("benchmark", "strategy", "query_id"), sort = FALSE)
    z[, `:=`(residual = value - question_mean,
      centering_constraint = "sum_of_valid_repeat_residuals_per_question_strategy_is_zero;five_or_four_repeats")]
    z
  })
  residuals <- data.table::rbindlist(residual_list)
  data.table::setorder(residuals, metric, run_id, source_query_record_index)
  rr <- r[kind == "run", .(run_id, process_start_ms = as.numeric(process_start_ms),
    process_end_ms = as.numeric(process_end_ms), task_first_query_ms = as.numeric(task_first_query_ms),
    task_last_query_ms = as.numeric(task_last_query_ms))]
  data.table::setorder(rr, process_start_ms)
  rr[, `:=`(chronological_order = seq_len(.N),
    process_start_utc = format(as.POSIXct(process_start_ms / 1000, origin = "1970-01-01", tz = "UTC"),
                             "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"))]
  run_diag <- residuals[, .(n_positions = .N, n_valid = sum(is.finite(value)),
    mean_value = mean(value, na.rm = TRUE), mean_residual = mean(residual, na.rm = TRUE),
    sd_residual = stats::sd(residual, na.rm = TRUE),
    min_residual = min(residual, na.rm = TRUE), max_residual = max(residual, na.rm = TRUE)),
    by = .(run_id, benchmark, strategy, repetition, metric)]
  run_diag <- merge(run_diag, rr, by = "run_id", sort = FALSE)
  data.table::setorder(run_diag, metric, chronological_order)
  residual_acf <- residuals[, diag_acf(residual), by = .(run_id, benchmark, strategy, repetition, metric)]
  residual_acf[, `:=`(sequence = "actual_source_query_record_order_NA_positions_preserved",
    centering_constraint = "question_strategy_repeat_centering_couples_repeats",
    interpretation = "descriptive_lag_association_no_significance_bands")]

  # Category composition and contiguous runs use the common actual question order.
  category_composition <- qo[benchmark == "mmlu_pro", .(n_questions = .N,
      fraction_of_benchmark = .N / 200, first_order = min(question_order),
      last_order = max(question_order), mean_order = mean(question_order),
      median_order = stats::median(question_order)), by = category]
  category_positions <- data.table::copy(qo[benchmark == "mmlu_pro"])
  category_positions[, block_id := data.table::rleid(category)]
  category_order_runs <- category_positions[, .(category = category[1L],
    first_order = min(question_order), last_order = max(question_order), n_questions = .N,
    query_ids = paste(query_id, collapse = ";")), by = block_id]

  accuracy_list <- list(); accuracy_details_list <- list()
  for (i in seq_len(nrow(accuracy))) {
    p <- accuracy[i]
    sides <- lapply(c(p$strategy_a, p$strategy_b), function(st) {
      z <- s[benchmark == p$benchmark & strategy == st,
        .(query_id, majority_correct = as.logical(majority_correct),
          correct_n_valid, correct_sum, correct_by_repetition,
          correctness_disagreement = as.logical(correctness_disagreement), run_ids)]
      diag_assert(all(z$correct_n_valid == 5L), "Incomplete correctness repetitions")
      z
    })
    data.table::setnames(sides[[1]], setdiff(names(sides[[1]]), "query_id"),
                        paste0(setdiff(names(sides[[1]]), "query_id"), "_a"))
    data.table::setnames(sides[[2]], setdiff(names(sides[[2]]), "query_id"),
                        paste0(setdiff(names(sides[[2]]), "query_id"), "_b"))
    z <- merge(sides[[1]], sides[[2]], by = "query_id")
    z <- merge(z, qo[benchmark == p$benchmark, .(query_id, question_order, category)], by = "query_id")
    z[, `:=`(comparison_id = p$comparison_id, benchmark = p$benchmark,
      strategy_a = p$strategy_a, strategy_b = p$strategy_b,
      discordant = majority_correct_a != majority_correct_b,
      paired_cell = ifelse(majority_correct_a & majority_correct_b, "both_correct",
        ifelse(majority_correct_a, "only_a_correct", ifelse(majority_correct_b, "only_b_correct", "both_wrong"))))]
    data.table::setorder(z, question_order)
    accuracy_details_list[[i]] <- z
    accuracy_list[[i]] <- z[, .(comparison_id = p$comparison_id, benchmark = p$benchmark,
      strategy_a = p$strategy_a, strategy_b = p$strategy_b, n = .N,
      both_correct = sum(paired_cell == "both_correct"),
      only_a_correct = sum(paired_cell == "only_a_correct"),
      only_b_correct = sum(paired_cell == "only_b_correct"),
      both_wrong = sum(paired_cell == "both_wrong"), discordant_pairs = sum(discordant),
      majority_accuracy_a = mean(majority_correct_a), majority_accuracy_b = mean(majority_correct_b),
      repeat_disagreement_questions_a = sum(correctness_disagreement_a),
      repeat_disagreement_questions_b = sum(correctness_disagreement_b),
      five_correctness_repeats_complete = all(correct_n_valid_a == 5L & correct_n_valid_b == 5L),
      discordant_question_orders = paste(question_order[discordant], collapse = ";"),
      discordant_query_ids = paste(query_id[discordant], collapse = ";"))]
  }
  accuracy_details <- data.table::rbindlist(accuracy_details_list)
  accuracy_category <- accuracy_details[, .(n = .N, discordant_pairs = sum(discordant),
      only_a_correct = sum(paired_cell == "only_a_correct"),
      only_b_correct = sum(paired_cell == "only_b_correct")),
    by = .(comparison_id, benchmark, strategy_a, strategy_b, category)]

  sensitivity_list <- list()
  sensitivity_specs <- plan[analysis_variant != "primary_method"]
  for (i in seq_len(nrow(sensitivity_specs))) {
    spec <- sensitivity_specs[i]
    p <- primary[comparison_id == spec$parent_comparison_id]
    diag_assert(nrow(p) == 1L && p$metric != "majority_correct", "Invalid sensitivity parent")
    primary_pair <- diag_pair(s, p$benchmark, p$strategy_a, p$strategy_b, p$metric)
    variant <- spec$analysis_variant
    if (variant == "whole_run_omission_collection") {
      exclude <- if (p$benchmark == "mmlu_pro" && p$metric %in% c("gpu_trapezoid_j", "cpu_j") &&
        "small_only" %in% c(p$strategy_a, p$strategy_b)) "3030" else NULL
      qq <- q[benchmark == p$benchmark & strategy %in% c(p$strategy_a, p$strategy_b)]
      reference <- diag_pair(qq, p$benchmark, p$strategy_a, p$strategy_b, p$metric,
                             excluded_query = exclude, summary = FALSE)
      for (side in c("A", "B")) {
        strategy_omit <- if (side == "A") p$strategy_a else p$strategy_b
        run_ids <- unique(qq[strategy == strategy_omit, run_id])
        run_ids <- rr[run_id %in% run_ids][order(process_start_ms)]$run_id
        diag_assert(length(run_ids) == 5L, "Whole-run omission requires exactly five real runs per side")
        for (run_omit in run_ids) {
          partial <- qq[run_id != run_omit]
          d <- diag_pair(partial, p$benchmark, p$strategy_a, p$strategy_b, p$metric,
                          excluded_query = exclude, summary = FALSE)
          row <- diag_sensitivity(d, reference, spec$comparison_id, p$comparison_id, variant,
            paste0("omit_", side, "_", run_omit), side, run_omit,
            if (is.null(exclude)) "" else exclude)
          row[, reference_policy := if (is.null(exclude)) "all_questions_all_runs" else
            "same_199_questions_all_runs;both_sides_query3030_excluded_before_run_omission"]
          sensitivity_list[[length(sensitivity_list) + 1L]] <- row
        }
      }
    } else {
      exclude <- if (variant %in% c("exclude_query3030", "left_hold_exclude_query3030")) "3030" else NULL
      method_metric <- if (variant %in% c("left_hold", "left_hold_exclude_query3030")) "gpu_left_j" else p$metric
      d <- diag_pair(s, p$benchmark, p$strategy_a, p$strategy_b, method_metric, excluded_query = exclude)
      row <- diag_sensitivity(d, primary_pair, spec$comparison_id, p$comparison_id, variant,
        variant, excluded_query = if (is.null(exclude)) "" else exclude)
      row[, reference_policy := "primary_trapezoid_or_cpu_all_200_questions_including_approved_four_repeat_mean"]
      sensitivity_list[[length(sensitivity_list) + 1L]] <- row
    }
  }
  sensitivity <- data.table::rbindlist(sensitivity_list, fill = TRUE)
  sensitivity <- merge(sensitivity,
    primary[, .(parent_comparison_id = comparison_id, benchmark, strategy_a, strategy_b, metric)],
    by = "parent_comparison_id", sort = FALSE)
  sensitivity[, unit := ifelse(metric == "latency_s", "s/query", "J/query")]
  diag_assert(nrow(sensitivity) == 420L && data.table::uniqueN(sensitivity$specification_id) == 60L,
              "Sensitivity specifications or scenario counts differ from the approved plan")
  diag_assert(nrow(paired) == 8000L && nrow(residuals) == 30000L &&
              nrow(run_diag) == 150L && nrow(residual_acf) == 1500L &&
              nrow(accuracy_details) == 2800L, "Unexpected diagnostic output row count")

  tables <- list(paired_differences = paired, diagnostics_summary = diagnostics_summary,
    leave_one_question = leave_one_question, query_residuals = residuals,
    run_diagnostics = run_diag, residual_acf = residual_acf,
    paired_difference_acf = paired_difference_acf, question_order = qo,
    category_composition = category_composition, category_positions = category_positions,
    category_differences = data.table::rbindlist(category_list), category_order_runs = category_order_runs,
    paired_accuracy_tables = data.table::rbindlist(accuracy_list),
    paired_accuracy_details = accuracy_details, accuracy_category_discordance = accuracy_category,
    sensitivity_point_estimates = sensitivity)
  if (!is.null(out)) {
    diag_assert(dir.exists(out), "Output directory must be created by the new stage entry")
    destinations <- file.path(out, paste0(names(tables), ".csv"))
    diag_assert(!any(file.exists(destinations)), "Refusing to overwrite diagnostic output files")
    for (i in seq_along(tables)) data.table::fwrite(tables[[i]], destinations[i], na = "NA", bom = FALSE)
  }
  tables
}
