# Inference adapter for the authorized clean, end-to-end reproduction.
# Reuses frozen statistical functions; historical numeric outputs are not read.
# The unified entry owns global protection, logs, invariants and final review.

run_inference_stage <- function(root, processing_dir, sensitivity_dir, out, plan, config) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  processing_dir <- normalizePath(processing_dir, winslash = "/", mustWork = TRUE)
  sensitivity_dir <- normalizePath(sensitivity_dir, winslash = "/", mustWork = TRUE)
  if (file.exists(out) || dir.exists(out)) stop("Inference stage refuses an existing output directory", call. = FALSE)
  out <- paste0(normalizePath(dirname(out), winslash = "/", mustWork = TRUE), "/", basename(out))
  within_analysis <- function(path) startsWith(tolower(path), paste0(tolower(root), "/analysis/"))
  if (!all(vapply(c(processing_dir, sensitivity_dir, out), within_analysis, logical(1))))
    stop("Inference inputs and output must be in the authorized analysis tree", call. = FALSE)
  forbidden_numeric <- file.path(root, c("analysis/outputs_20261017_02", "analysis/diagnostics_outputs_20261017_01"))
  if (any(tolower(c(processing_dir, sensitivity_dir)) %in% tolower(forbidden_numeric)))
    stop("This stage must consume this reproduction's new numeric tables", call. = FALSE)
  stage <- file.path(root, "analysis/inference_20261017")
  imported_modules <- file.path(stage, c("continuous_core.R", "accuracy_methods.R", "figures_corrected.R"))
  if (!all(file.exists(imported_modules))) stop("A frozen inference module is missing", call. = FALSE)
  methods <- new.env(parent = globalenv())
  for (path in imported_modules) source(path, local = methods, encoding = "UTF-8", keep.source = FALSE)
  assert <- function(condition, detail) if (!isTRUE(condition)) stop(detail, call. = FALSE)
  hash <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
  utc <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
  relative <- function(path) {
    path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    if (startsWith(tolower(path), paste0(tolower(root), "/"))) substring(path, nchar(root) + 2L) else path
  }
  read_csv <- function(path) data.table::fread(path, na.strings = c("NA", ""), encoding = "UTF-8")

  # Only approved static specifications may come from historical directories.
  source_plan_path <- file.path(root, "analysis/descriptive_20261017/planned_comparisons.csv")
  approved_plan_path <- file.path(root, "analysis/descriptive_outputs_20261017_01/planned_comparisons.csv")
  approved_config_path <- file.path(root, "analysis/inference_outputs_20261017_02/inference_config.json")
  source_plan <- read_csv(source_plan_path)
  approved_plan <- read_csv(approved_plan_path)
  plan <- data.table::copy(data.table::as.data.table(plan))
  semantic_equal <- function(a, b) {
    if (!identical(names(a), names(b)) || nrow(a) != nrow(b) || anyDuplicated(a$comparison_id) || anyDuplicated(b$comparison_id)) return(FALSE)
    a <- a[order(comparison_id)]; b <- b[order(comparison_id)]
    values <- function(x) { x <- as.character(x); x[!is.na(x) & x == ""] <- NA_character_; x }
    all(vapply(names(a), function(nm) identical(values(a[[nm]]), values(b[[nm]])), logical(1)))
  }
  assert(semantic_equal(plan, source_plan) && semantic_equal(plan, approved_plan), "Supplied/static/approved comparison plans differ")
  main_plan <- plan[analysis_variant == "primary_method"]
  assert(nrow(plan) == 114L && nrow(main_plan) == 54L &&
           sum(main_plan$metric == "majority_correct") == 14L && all(main_plan$alternative == "two.sided"),
         "The approved 54 formal and 60 sensitivity specifications must be preserved")
  confirmed <- jsonlite::fromJSON(approved_config_path)
  fixed_fields <- c("alpha", "confidence_level", "hac_lags", "hac_prewhite", "hac_adjust", "hac_critical_value", "family_sizes")
  assert(all(fixed_fields %in% names(config)) && all(fixed_fields %in% names(confirmed)), "Missing explicitly frozen numerical configuration")
  cfg <- methods$inference_fixed_config(confirmed)
  methods$inference_fixed_config(config)
  method_fields <- c("target", "alternative", "pairing_key", "missing_rule", "accuracy_method", "accuracy_ci",
                     "hac_kernel", "hac_order", "ci_multiplicity", "effect_continuous", "effect_accuracy", "post_data_plan")
  for (field in method_fields) {
    assert(!is.null(confirmed[[field]]), paste("Missing approved configuration field", field))
    if (!is.null(config[[field]])) assert(isTRUE(all.equal(config[[field]], confirmed[[field]], check.attributes = FALSE)),
                                        paste("Changed approved configuration field", field))
    cfg[[field]] <- confirmed[[field]]
  }
  # Rebuild provenance rather than copying the original execution time/input.
  cfg$created_utc <- utc()
  cfg$input_directory <- relative(processing_dir)
  cfg$sensitivity_directory <- relative(sensitivity_dir)
  cfg$comparison_plan <- relative(source_plan_path)
  cfg$comparison_plan_sha256 <- hash(source_plan_path)
  cfg$approved_config_source <- relative(approved_config_path)
  cfg$approved_config_sha256 <- hash(approved_config_path)
  cfg$stage_role <- "inference_from_current_reproduction_processing_and_sensitivity"
  cfg$old_numeric_outputs_read <- FALSE

  query_path <- file.path(processing_dir, "query_metrics.csv")
  summary_path <- file.path(processing_dir, "question_summary.csv")
  sensitivity_path <- file.path(sensitivity_dir, "sensitivity_point_estimates.csv")
  q <- read_csv(query_path); s <- read_csv(summary_path); sens <- read_csv(sensitivity_path)
  q[, query_id := as.character(query_id)]; s[, query_id := as.character(query_id)]
  assert(nrow(q) == 10000L && nrow(s) == 2000L && nrow(sens) == 420L,
         "Current-stage table counts do not match the reviewed design")
  assert(!anyDuplicated(q[, .(benchmark, strategy, repetition, query_id)]) &&
           !anyDuplicated(s[, .(benchmark, strategy, query_id)]), "Current-stage pairing keys are not unique")
  assert(data.table::uniqueN(sens$specification_id) == 60L &&
           !anyDuplicated(sens[, .(specification_id, scenario)]) &&
           setequal(sens$specification_id, plan[analysis_variant != "primary_method", comparison_id]) &&
           setequal(sens$parent_comparison_id, main_plan[metric != "majority_correct", comparison_id]),
         "Current sensitivity scenarios do not match all approved specifications/parents")
  assert(dir.create(out, recursive = FALSE), "Cannot create fresh inference output")
  safe_csv <- function(x, name) {
    path <- file.path(out, name)
    assert(!file.exists(path), paste("Refusing to overwrite", path))
    data.table::fwrite(x, path, na = "NA")
  }
  json_cfg <- cfg; json_cfg$family_sizes <- as.list(cfg$family_sizes)
  jsonlite::write_json(json_cfg, file.path(out, "inference_config.json"), pretty = TRUE, auto_unbox = TRUE, na = "null")
  safe_csv(main_plan, "comparison_specifications.csv")
  input_paths <- c(query_path, summary_path, sensitivity_path, source_plan_path, approved_plan_path, approved_config_path)
  safe_csv(data.table::data.table(path = vapply(input_paths, relative, character(1)),
    sha256 = vapply(input_paths, hash, character(1)),
    role = c("current_processing_queries", "current_processing_question_means", "current_sensitivity_point_estimates",
             "static_source_comparison_plan", "approved_static_plan_reference", "approved_static_method_configuration")),
    "inference_input_hashes.csv")
  safe_csv(data.table::data.table(path = vapply(imported_modules, relative, character(1)),
    sha256 = vapply(imported_modules, hash, character(1))), "reused_inference_modules.csv")

  continuous <- methods$run_continuous_inference(q, s, plan, cfg)
  acc_plan <- main_plan[metric == "majority_correct"]
  accuracy <- data.table::rbindlist(lapply(seq_len(nrow(acc_plan)), function(i) {
    spec <- acc_plan[i]
    bm <- spec$benchmark; sta <- spec$strategy_a; stb <- spec$strategy_b
    xa <- s[benchmark == bm & strategy == sta, .(benchmark, query_id, correct_a = majority_correct)]
    xb <- s[benchmark == bm & strategy == stb, .(benchmark, query_id, correct_b = majority_correct)]
    paired <- merge(xa, xb, by = c("benchmark", "query_id"), all = TRUE, sort = FALSE)
    assert(nrow(paired) == 200L && !anyDuplicated(paired[, .(benchmark, query_id)]) && !anyNA(paired),
           "Illegal accuracy pairing after unified preflight")
    result <- data.table::as.data.table(methods$accuracy_inference_counts(sum(paired$correct_a & paired$correct_b),
      sum(paired$correct_a & !paired$correct_b), sum(!paired$correct_a & paired$correct_b),
      sum(!paired$correct_a & !paired$correct_b)))
    meta <- spec[, .(comparison_id, rq, benchmark, metric, strategy_a, strategy_b, priority,
      family_id, planned_family_size = family_size, alternative, n_questions_planned)]
    ans <- cbind(meta, result)
    ans[, `:=`(difference_orientation = "A_minus_B", ci_target = "paired_majority_accuracy_A_minus_B_percentage_points",
                effect_definition = "100*(b-c)/n_percentage_points")]
    ans
  }), fill = TRUE)
  primary <- methods$apply_planned_holm(data.table::rbindlist(list(continuous$continuous, accuracy), fill = TRUE), cfg)
  primary[, `:=`(reject_h0_holm = reject_h0, execution_scope = cfg$target)]
  data.table::setorder(primary, family_id, comparison_id)
  hac <- methods$apply_planned_holm(continuous$hac, cfg, c("lag", "family_id"))
  hac[, reject_h0_holm := reject_h0]
  hac <- merge(hac, primary[, .(comparison_id, primary_p_raw = p_raw, primary_p_holm = p_holm,
                          primary_reject_h0_holm = reject_h0_holm)], by = "comparison_id", all.x = TRUE, sort = FALSE)
  hac[, holm_decision_changed := reject_h0_holm != primary_reject_h0_holm]
  data.table::setorder(hac, comparison_id, lag)
  cross <- merge(sens, primary[, .(parent_comparison_id = comparison_id, primary_mean_difference = mean_difference,
    primary_p_raw = p_raw, primary_p_holm = p_holm, primary_reject_h0_holm = reject_h0_holm)],
    by = "parent_comparison_id", all.x = TRUE, sort = FALSE)
  cross[, `:=`(point_estimates_recomputed = FALSE, sensitivity_p_or_ci_computed = FALSE,
    point_estimates_origin = "current_reproduction_sensitivity_stage",
    point_estimates_recomputed_scope = "inference_substage_only",
    source_path = relative(sensitivity_path), source_sha256 = hash(sensitivity_path),
    sign_changed_vs_own_reference = sign(estimate) != sign(reference_estimate))]
  hs <- hac[, .(n_lags = .N, n_success = sum(status == "ok"),
    se_ratio_min = if (any(is.finite(se_ratio))) min(se_ratio[is.finite(se_ratio)]) else NA_real_,
    se_ratio_max = if (any(is.finite(se_ratio))) max(se_ratio[is.finite(se_ratio)]) else NA_real_,
    any_holm_decision_changed = if (all(is.na(holm_decision_changed))) NA else any(holm_decision_changed, na.rm = TRUE),
    changed_lags = paste(lag[which(holm_decision_changed)], collapse = ";")),
    by = .(comparison_id, rq, benchmark, metric, strategy_a, strategy_b)]
  assert(nrow(primary) == 54L && !anyDuplicated(primary$comparison_id) &&
           setequal(primary$comparison_id, main_plan$comparison_id), "Primary comparison rows changed")
  assert(nrow(hac) == 120L && !anyDuplicated(hac[, .(comparison_id, lag)]) && all(table(hac$comparison_id) == 3L),
         "HAC row/lag specifications changed")
  assert(nrow(cross) == 420L && nrow(continuous$paired) == 8000L, "Crosswalk or paired-source rows changed")
  for (tab in list(primary, hac)) {
    ok <- tab$status == "ok"
    assert(all(is.finite(tab$p_raw[ok]) & tab$p_raw[ok] >= 0 & tab$p_raw[ok] <= 1 &
                 tab$p_holm[ok] >= tab$p_raw[ok] & tab$p_holm[ok] <= 1), "Invalid p/Holm values")
    assert(all(is.finite(tab$ci_low[ok]) & is.finite(tab$ci_high[ok]) &
                 tab$ci_low[ok] <= tab$mean_difference[ok] & tab$ci_high[ok] >= tab$mean_difference[ok]),
           "Invalid inference interval")
    assert(all(is.na(tab$p_raw[!ok]) & is.na(tab$p_holm[!ok]) & nzchar(tab$reason[!ok])),
           "Failed comparisons must retain NA and reasons")
  }
  safe_csv(primary[metric != "majority_correct"], "continuous_tests.csv")
  safe_csv(primary[metric == "majority_correct"], "accuracy_tests.csv")
  safe_csv(primary, "all_primary_tests.csv")
  safe_csv(hac, "hac_sensitivity.csv")
  safe_csv(cross, "sensitivity_crosswalk.csv")
  safe_csv(continuous$paired, "paired_inference_inputs.csv")
  safe_csv(hs, "hac_summary.csv")
  figures <- methods$make_inference_figures(out)
  safe_csv(figures, "figures_index.csv")
  invisible(list(primary = primary, hac = hac, sensitivity_crosswalk = cross,
                 figures = figures, config = cfg, output = out,
                 historical_tests_reexecuted = FALSE, historical_independent_audit_reexecuted = FALSE))
}
