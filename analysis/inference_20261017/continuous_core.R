# Authorized conditional inference on reviewed question means only.
# Pure functions: no filesystem writes, no integration, no model execution.

inf_assert <- function(ok, message) {
  if (!isTRUE(ok)) stop(message, call. = FALSE)
}

inference_fixed_config <- function(config = list()) {
  expected <- list(alpha = 0.05, confidence_level = 0.95,
    hac_lags = c(5L, 10L, 20L), hac_prewhite = FALSE, hac_adjust = TRUE,
    hac_critical_value = 1.96,
    family_sizes = c(F_RQ1_ENERGY = 24L, F_RQ11_ACCURACY = 12L,
                     F_RQ2_TRADEOFF = 6L, F_RQ3_LATENCY = 12L))
  for (nm in intersect(names(config), names(expected))) {
    value <- config[[nm]]
    if (nm == "family_sizes") {
      value <- unlist(value)
      inf_assert(setequal(names(value), names(expected[[nm]])), "Unapproved family names")
      value <- value[names(expected[[nm]])]
    } else value <- unlist(value)
    inf_assert(isTRUE(all.equal(value, expected[[nm]], check.attributes = FALSE)),
               paste("Unapproved inference configuration:", nm))
  }
  expected
}

inf_plan_row <- function(plan_row) {
  p <- data.table::copy(data.table::as.data.table(plan_row))
  inf_assert(nrow(p) == 1L, "Expected one comparison specification")
  req <- c("comparison_id", "benchmark", "metric", "strategy_a", "strategy_b",
           "family_id", "family_size", "n_questions_planned", "alternative")
  inf_assert(all(req %in% names(p)), "Incomplete comparison specification")
  inf_assert(identical(as.character(p$alternative), "two.sided"), "Only two-sided comparisons are authorized")
  inf_assert(p$strategy_a != p$strategy_b, "A and B must be distinct strategies")
  p
}

pair_continuous_inputs <- function(q, s, plan_row) {
  p <- inf_plan_row(plan_row)
  q <- data.table::copy(data.table::as.data.table(q))
  s <- data.table::copy(data.table::as.data.table(s))
  metric_name <- as.character(p$metric)
  field <- switch(metric_name, gpu_trapezoid_j = "gpu_trapezoid_j_mean",
                  cpu_j = "cpu_j_mean", latency_s = "latency_ms_mean",
                  stop("Unsupported continuous metric", call. = FALSE))
  valid_field <- sub("_mean$", "_n_valid", field)
  keys <- c("benchmark", "query_id")
  inf_assert(all(c(keys, "strategy", field, valid_field, "run_ids") %in% names(s)),
             "Missing question summary fields")
  inf_assert(all(c(keys, "strategy", "run_id", "repetition", "source_query_record_index",
                   "source_query_path", "source_query_sha256") %in% names(q)),
             "Missing original-order or source fields")
  bm <- as.character(p$benchmark)
  a_name <- as.character(p$strategy_a); b_name <- as.character(p$strategy_b)
  s[, query_id := as.character(query_id)]
  q[, query_id := as.character(query_id)]
  side <- function(strategy_name, suffix) {
    x <- s[benchmark == bm & strategy == strategy_name]
    inf_assert(!anyDuplicated(x[, ..keys]), "Duplicate summary pairing key")
    inf_assert(nrow(x) == as.integer(p$n_questions_planned), "Unexpected summary question count")
    value <- suppressWarnings(as.numeric(x[[field]]))
    if (metric_name == "latency_s") value <- value / 1000
    x <- data.table::data.table(benchmark = x$benchmark, query_id = x$query_id,
      value = value, n_valid = as.integer(x[[valid_field]]), run_ids = as.character(x$run_ids))
    data.table::setnames(x, c("value", "n_valid", "run_ids"),
                        paste0(c("value_", "n_valid_", "run_ids_"), suffix))
    source <- q[benchmark == bm & strategy == strategy_name]
    inf_assert(!anyDuplicated(source[, .(benchmark, strategy, repetition, query_id)]),
               "Duplicate query repetition key")
    inf_assert(setequal(source$query_id, x$query_id), "Source query set differs from summary")
    original_order <- source[, .(
      n_orders = data.table::uniqueN(source_query_record_index),
      question_order = as.integer(source_query_record_index[1L]),
      source_query_paths = paste(sort(unique(source_query_path)), collapse = ";"),
      source_query_sha256 = paste(sort(unique(source_query_sha256)), collapse = ";")
    ), by = .(benchmark, query_id)]
    inf_assert(all(original_order$n_orders == 1L), "Question positions differ across recorded runs")
    inf_assert(all(is.finite(original_order$question_order)) &&
                 setequal(original_order$question_order, seq_len(nrow(original_order))),
               "Original record positions are not a complete ordered sequence")
    original_order[, n_orders := NULL]
    data.table::setnames(original_order, c("question_order", "source_query_paths", "source_query_sha256"),
                        paste0(c("question_order_", "source_query_paths_", "source_query_sha256_"), suffix))
    merge(x, original_order, by = keys, sort = FALSE, all = TRUE)
  }
  a <- side(a_name, "a"); b <- side(b_name, "b")
  inf_assert(setequal(a$query_id, b$query_id), "Paired question sets differ")
  paired <- merge(a, b, by = keys, sort = FALSE, all = TRUE)
  inf_assert(nrow(paired) == as.integer(p$n_questions_planned), "Illegal paired row count")
  inf_assert(all(paired$question_order_a == paired$question_order_b), "A/B original question orders differ")
  paired[, `:=`(question_order = question_order_a, difference = value_a - value_b,
                 comparison_id = as.character(p$comparison_id), strategy_a = a_name,
                 strategy_b = b_name, metric = metric_name,
                 unit = if (metric_name == "latency_s") "s/query" else "J/query")]
  data.table::setorder(paired, question_order)
  paired
}

continuous_test_one <- function(value_a, value_b, config = list()) {
  cfg <- inference_fixed_config(config)
  ans <- data.table::data.table(n_pairs = length(value_a), mean_a = NA_real_, mean_b = NA_real_,
    mean_difference = NA_real_, sd_difference = NA_real_, standard_error = NA_real_,
    t_statistic = NA_real_, df = NA_real_, p_raw = NA_real_, ci_low = NA_real_, ci_high = NA_real_,
    relative_change_pct = NA_real_, relative_change_status = "unavailable",
    cohens_dz = NA_real_, status = "failed", reason = "")
  fail <- function(why) { ans[, reason := why]; ans }
  if (!is.numeric(value_a) || !is.numeric(value_b)) return(fail("non_numeric_input"))
  if (length(value_a) != length(value_b) || length(value_a) < 2L) return(fail("illegal_pair_count"))
  if (any(!is.finite(value_a)) || any(!is.finite(value_b))) return(fail("missing_or_nonfinite_input"))
  d <- value_a - value_b
  if (any(!is.finite(d))) return(fail("nonfinite_difference"))
  n <- length(d); m <- mean(d); sd_d <- stats::sd(d); ma <- mean(value_a); mb <- mean(value_b)
  if (any(!is.finite(c(m, sd_d, ma, mb)))) return(fail("nonfinite_descriptive_arithmetic"))
  ans[, `:=`(mean_a = ma, mean_b = mb, mean_difference = m, sd_difference = sd_d)]
  if (mb != 0 && is.finite(100 * m / mb)) {
    ans[, `:=`(relative_change_pct = 100 * m / mb, relative_change_status = "ok")]
  } else ans[, relative_change_status := if (mb == 0) "zero_reference_mean" else "nonfinite_ratio"]
  if (sd_d <= 0) return(fail("zero_difference_variance"))
  se <- sd_d / sqrt(n)
  if (!is.finite(se) || se <= 0) return(fail("invalid_standard_error"))
  if (se < 10 * .Machine$double.eps * abs(m)) return(fail("numerically_constant_difference"))
  tt <- m / se; df_value <- n - 1L; critical <- stats::qt((1 + cfg$confidence_level) / 2, df_value)
  pp <- 2 * stats::pt(-abs(tt), df_value); ci <- m + c(-1, 1) * critical * se; dz <- m / sd_d
  if (any(!is.finite(c(tt, pp, ci, dz)))) return(fail("nonfinite_inference_arithmetic"))
  ans[, `:=`(standard_error = se, t_statistic = tt, df = df_value, p_raw = pp,
             ci_low = ci[1L], ci_high = ci[2L], cohens_dz = dz, status = "ok", reason = "")]
  ans
}

hac_test_one <- function(difference, question_order, lag, paired_t_standard_error = NA_real_, config = list()) {
  cfg <- inference_fixed_config(config)
  ans <- data.table::data.table(n_pairs = length(difference), lag = as.integer(lag),
    kernel = "Bartlett", prewhite = FALSE, adjust = TRUE, hac_critical_value = cfg$hac_critical_value,
    mean_difference = NA_real_, hac_variance = NA_real_, hac_standard_error = NA_real_,
    paired_t_standard_error = paired_t_standard_error, se_ratio = NA_real_, z_statistic = NA_real_,
    p_raw = NA_real_, ci_low = NA_real_, ci_high = NA_real_, status = "failed", reason = "")
  fail <- function(why, status_value = "failed") { ans[, `:=`(reason = why, status = status_value)]; ans }
  if (!(length(lag) == 1L && lag %in% cfg$hac_lags)) return(fail("unapproved_hac_lag"))
  if (!is.numeric(difference) || length(difference) != length(question_order) ||
      length(difference) <= lag || any(!is.finite(difference))) return(fail("invalid_hac_input"))
  if (any(!is.finite(question_order)) || anyDuplicated(question_order) ||
      !setequal(question_order, seq_along(difference))) return(fail("invalid_original_question_order"))
  d <- difference[order(question_order)]
  ans[, mean_difference := mean(d)]
  if (stats::sd(d) == 0) return(fail("zero_difference_variance"))
  if (!requireNamespace("sandwich", quietly = TRUE)) return(fail("sandwich_not_available", "not_executed_dependency"))
  covariance <- tryCatch({
    fit <- stats::lm(d ~ 1)
    sandwich::NeweyWest(fit, lag = as.integer(lag), prewhite = FALSE, adjust = TRUE)
  }, error = function(e) e)
  if (inherits(covariance, "error")) return(fail(paste0("NeweyWest_error: ", conditionMessage(covariance))))
  if (!is.matrix(covariance) || !identical(dim(covariance), c(1L, 1L)) ||
      !is.finite(covariance[1L, 1L]) || covariance[1L, 1L] <= 0) return(fail("invalid_hac_covariance"))
  vv <- as.numeric(covariance[1L, 1L]); se <- sqrt(vv); m <- mean(d); zz <- m / se
  pp <- 2 * stats::pnorm(-abs(zz)); ci <- m + c(-1, 1) * cfg$hac_critical_value * se
  if (any(!is.finite(c(vv, se, zz, pp, ci)))) return(fail("nonfinite_hac_arithmetic"))
  ratio <- if (length(paired_t_standard_error) == 1L && is.finite(paired_t_standard_error) &&
                  paired_t_standard_error > 0) se / paired_t_standard_error else NA_real_
  ans[, `:=`(hac_variance = vv, hac_standard_error = se, se_ratio = ratio, z_statistic = zz,
             p_raw = pp, ci_low = ci[1L], ci_high = ci[2L], status = "ok", reason = "")]
  ans
}

apply_planned_holm <- function(x, config = list(), group_cols = "family_id") {
  cfg <- inference_fixed_config(config)
  out <- data.table::copy(data.table::as.data.table(x))
  inf_assert(all(c(group_cols, "family_id", "p_raw") %in% names(out)), "Missing Holm input columns")
  inf_assert("family_id" %in% group_cols, "Holm grouping must include the original family")
  inf_assert(all(out$family_id %in% names(cfg$family_sizes)), "Unapproved Holm family")
  expected_sizes <- as.integer(cfg$family_sizes[as.character(out$family_id)])
  if ("planned_family_size" %in% names(out)) {
    inf_assert(all(out$planned_family_size == expected_sizes), "Changed planned Holm family size")
  }
  if ("family_size" %in% names(out)) {
    inf_assert(all(out$family_size == expected_sizes), "Changed original Holm family size")
  }
  inf_assert(all(is.na(out$p_raw) | (is.finite(out$p_raw) & out$p_raw >= 0 & out$p_raw <= 1)), "Invalid raw p-value")
  out[, `:=`(planned_family_size = expected_sizes, p_holm = NA_real_, reject_h0 = NA,
              adjustment = "Holm_with_planned_family_size", alpha = cfg$alpha)]
  indices <- out[, .(indices = list(.I)), by = group_cols]
  for (ii in indices$indices) {
    planned <- unique(out$planned_family_size[ii])
    inf_assert(length(planned) == 1L && length(ii) <= planned, "Holm group exceeds its planned family")
    ok <- ii[!is.na(out$p_raw[ii])]
    if (length(ok)) {
      adjusted <- stats::p.adjust(out$p_raw[ok], method = "holm", n = planned)
      out[ok, `:=`(p_holm = adjusted, reject_h0 = adjusted <= cfg$alpha)]
    }
  }
  out
}

run_continuous_inference <- function(q, s, plan, config = list()) {
  cfg <- inference_fixed_config(config)
  p <- data.table::copy(data.table::as.data.table(plan))
  inf_assert("analysis_variant" %in% names(p), "Missing analysis variant")
  p <- p[analysis_variant == "primary_method" & metric %in% c("gpu_trapezoid_j", "cpu_j", "latency_s")]
  inf_assert(!anyDuplicated(p$comparison_id), "Duplicate continuous comparison ID")
  continuous <- list(); hac <- list(); pairs <- list()
  for (i in seq_len(nrow(p))) {
    spec <- p[i]
    paired <- tryCatch(pair_continuous_inputs(q, s, spec), error = function(e) e)
    if (inherits(paired, "error")) {
      result <- continuous_test_one(numeric(), numeric(), cfg)
      result[, `:=`(status = "failed", reason = paste0("pairing_error: ", conditionMessage(paired)))]
    } else {
      pairs[[length(pairs) + 1L]] <- paired
      result <- continuous_test_one(paired$value_a, paired$value_b, cfg)
    }
    metadata <- spec[, .(comparison_id, rq, benchmark, metric, strategy_a, strategy_b,
                         priority, family_id, planned_family_size = as.integer(family_size),
                         alternative, n_questions_planned)]
    result <- cbind(metadata, result)
    result[, `:=`(method = "conditional_question_paired_t", confidence_level = cfg$confidence_level,
      ci_multiplicity = "unadjusted_pointwise", ci_target = "conditional_mean_A_minus_B",
      unit = if (metric == "latency_s") "s/query" else "J/query",
      difference_orientation = "A_minus_B", effect_definition = "Cohens_dz=mean(D)/sd(D)")]
    continuous[[length(continuous) + 1L]] <- result
    for (lag_value in cfg$hac_lags) {
      if (inherits(paired, "error") || result$status != "ok") {
        h <- hac_test_one(numeric(), numeric(), lag_value, config = cfg)
        h[, `:=`(n_pairs = result$n_pairs, reason = paste0("primary_input_unavailable: ", result$reason))]
      } else h <- hac_test_one(paired$difference, paired$question_order, lag_value, result$standard_error, cfg)
      h <- cbind(metadata, h)
      h[, `:=`(method = "NeweyWest_intercept_asymptotic_normal", confidence_level = cfg$confidence_level,
        ci_multiplicity = "unadjusted_pointwise", ci_target = "conditional_mean_A_minus_B",
        unit = if (metric == "latency_s") "s/query" else "J/query",
        difference_orientation = "A_minus_B", order_source = "source_query_record_index")]
      hac[[length(hac) + 1L]] <- h
    }
  }
  list(continuous = data.table::rbindlist(continuous, fill = TRUE),
       hac = data.table::rbindlist(hac, fill = TRUE), paired = data.table::rbindlist(pairs, fill = TRUE))
}
