# Reproduce only the 60 approved sensitivity specifications from THIS RUN'S
# processing tables. Historical numeric sensitivity outputs are never inputs.
# The module defines one function and has no command-line or source-time action.

run_sensitivity_stage <- function(root, processing_dir, out, plan) {
  require_packages <- c("data.table", "digest", "jsonlite")
  for (package_name in require_packages) {
    if (!requireNamespace(package_name, quietly = TRUE))
      stop("Required sensitivity dependency unavailable: ", package_name, call. = FALSE)
  }
  assert <- function(ok, message) if (!isTRUE(ok)) stop(message, call. = FALSE)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  processing_dir <- normalizePath(processing_dir, winslash = "/", mustWork = TRUE)
  assert(!file.exists(out), "Sensitivity output path exists; refusing overwrite")
  output_parent <- normalizePath(dirname(out), winslash = "/", mustWork = TRUE)
  out <- file.path(output_parent, basename(out))
  assert(startsWith(tolower(out), paste0(tolower(root), "/analysis/")),
         "Sensitivity output must be a new subdirectory under analysis")
  assert(startsWith(tolower(processing_dir), paste0(tolower(root), "/analysis/")),
         "Sensitivity inputs must be processing outputs under analysis")
  assert(!identical(tolower(processing_dir), tolower(file.path(root, "analysis/outputs_20261017_02"))),
         "This reproduction stage requires newly generated processing inputs, not the reviewed historical output")

  source_module <- file.path(root, "analysis/diagnostics_20261017/core.R")
  static_plan_path <- file.path(root, "analysis/descriptive_20261017/planned_comparisons.csv")
  adapter_path <- file.path(root, "analysis/reproduction_20261018/sensitivity_stage.R")
  processing_files <- file.path(processing_dir,
    c("query_metrics.csv", "question_summary.csv", "run_reconciliation.csv"))
  sources <- c(source_module, static_plan_path, adapter_path, processing_files)
  assert(all(file.exists(sources)), "Sensitivity source module, static specification or new processing input missing")
  hash <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
  hashes_before <- unname(vapply(sources, hash, character(1)))
  source_records <- data.table::data.table(
    role = c("reused_pure_function_module", "static_comparison_specification", "new_sensitivity_adapter",
             "new_query_metrics", "new_question_summary", "new_run_reconciliation"),
    path = sources, sha256 = hashes_before)

  canonical_plan <- data.table::fread(static_plan_path, na.strings = "NA", encoding = "UTF-8")
  if (is.character(plan) && length(plan) == 1L) {
    supplied_plan_path <- normalizePath(plan, winslash = "/", mustWork = TRUE)
    assert(identical(hash(supplied_plan_path), hash(static_plan_path)),
           "Supplied plan file differs from the static approved specification")
    supplied_plan <- data.table::fread(supplied_plan_path, na.strings = "NA", encoding = "UTF-8")
  } else supplied_plan <- data.table::as.data.table(data.table::copy(plan))
  assert(identical(names(supplied_plan), names(canonical_plan)) && nrow(supplied_plan) == nrow(canonical_plan),
         "Supplied comparison table schema or size differs from static specification")
  assert(!anyDuplicated(supplied_plan[["comparison_id"]]) && !anyDuplicated(canonical_plan[["comparison_id"]]),
         "Duplicate comparison IDs in specification")
  supplied_order <- order(supplied_plan[["comparison_id"]])
  canonical_order <- order(canonical_plan[["comparison_id"]])
  for (field_name in names(canonical_plan)) {
    assert(identical(as.character(supplied_plan[[field_name]][supplied_order]),
                     as.character(canonical_plan[[field_name]][canonical_order])),
           paste("Supplied comparison specification differs in field", field_name))
  }
  # Keep the approved file's original order for stable scenario serialization.
  plan <- canonical_plan
  primary <- plan[plan[["analysis_variant"]] == "primary_method"]
  sensitivity_specs <- plan[plan[["analysis_variant"]] != "primary_method"]
  assert(nrow(primary) == 54L && nrow(sensitivity_specs) == 60L,
         "Expected 54 main comparisons and 60 sensitivity specifications")
  expected_variants <- c(left_hold = 14L, exclude_query3030 = 4L,
    left_hold_exclude_query3030 = 2L, whole_run_omission_collection = 40L)
  observed_variants <- table(sensitivity_specs[["analysis_variant"]])
  assert(setequal(names(observed_variants), names(expected_variants)) &&
           all(as.integer(observed_variants[names(expected_variants)]) == unname(expected_variants)),
         "Sensitivity variant counts differ from the approved 14/4/2/40 specification")

  # Fail before source() if the historical module ever acquires top-level work.
  # Every top-level expression in the inspected version is a function definition.
  parsed_module <- parse(source_module, encoding = "UTF-8", keep.source = FALSE)
  definition_only <- vapply(as.list(parsed_module), function(expression) {
    is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
      is.symbol(expression[[2L]]) && is.call(expression[[3L]]) &&
      identical(expression[[3L]][[1L]], as.name("function"))
  }, logical(1))
  assert(length(definition_only) > 0L && all(definition_only),
         "Historical helper module is no longer pure function definitions; source was not executed")
  helpers <- new.env(parent = globalenv())
  source(source_module, local = helpers, encoding = "UTF-8", chdir = FALSE)
  assert(is.function(helpers$diag_pair) && is.function(helpers$diag_sensitivity),
         "Required pure sensitivity helpers unavailable")
  pair_questions <- helpers$diag_pair
  sensitivity_row <- helpers$diag_sensitivity
  # compute_diagnostics(), diag_acf() and all historical test functions are not called.

  q <- data.table::fread(processing_files[1L], na.strings = "NA",
                        colClasses = c(query_id = "character"))
  s <- data.table::fread(processing_files[2L], na.strings = "NA",
                        colClasses = c(query_id = "character"))
  r <- data.table::fread(processing_files[3L], na.strings = "NA")
  assert(nrow(q) == 10000L && nrow(s) == 2000L && nrow(r) == 55L,
         "New processing tables have unexpected 10000/2000/55 row counts")
  assert(!anyDuplicated(q[, .(benchmark, strategy, repetition, query_id)]) &&
           !anyDuplicated(s[, .(benchmark, strategy, query_id)]) && !anyDuplicated(r[["run_id"]]),
         "New processing tables have duplicate association keys")
  missing_expected_run <- "012_small_only__mmlu_pro__rep4"
  for (metric_name in c("gpu_trapezoid_j", "gpu_left_j", "cpu_j")) {
    values <- as.numeric(q[[metric_name]])
    missing_positions <- which(is.na(values))
    assert(length(missing_positions) == 1L &&
      q[["run_id"]][missing_positions] == missing_expected_run && q[["query_id"]][missing_positions] == "3030" &&
      all(is.finite(values[-missing_positions])), "Unexpected complete-energy missingness in new processing data")
  }
  assert(all(is.finite(as.numeric(q[["latency_ms"]]))), "New processing latency contains missing/non-finite values")
  rr <- r[r[["kind"]] == "run", .(run_id, process_start_ms = as.numeric(process_start_ms))]
  assert(nrow(rr) == 50L && all(is.finite(rr[["process_start_ms"]])), "Formal run ordering evidence is incomplete")
  data.table::setorder(rr, process_start_ms)

  rows <- list()
  for (specification_position in seq_len(nrow(sensitivity_specs))) {
    spec <- sensitivity_specs[specification_position]
    parent_positions <- which(primary[["comparison_id"]] == spec[["parent_comparison_id"]])
    assert(length(parent_positions) == 1L, "Sensitivity parent is missing or duplicated")
    p <- primary[parent_positions]
    assert(p[["metric"]] != "majority_correct", "Accuracy sensitivities are outside this fixed specification")
    base_pairs <- pair_questions(s, p$benchmark, p$strategy_a, p$strategy_b, p$metric)
    variant <- spec[["analysis_variant"]]
    if (variant == "whole_run_omission_collection") {
      excluded_question <- if (p$benchmark == "mmlu_pro" &&
        p$metric %in% c("gpu_trapezoid_j", "cpu_j") &&
        "small_only" %in% c(p$strategy_a, p$strategy_b)) "3030" else NULL
      query_positions <- which(q[["benchmark"]] == p$benchmark &
        q[["strategy"]] %in% c(p$strategy_a, p$strategy_b))
      selected_queries <- q[query_positions]
      reference <- pair_questions(selected_queries, p$benchmark, p$strategy_a, p$strategy_b,
                                  p$metric, excluded_query = excluded_question, summary = FALSE)
      expected_questions <- if (is.null(excluded_question)) 200L else 199L
      assert(nrow(reference) == expected_questions, "Whole-run reference question count changed")
      for (omitted_side in c("A", "B")) {
        omitted_strategy <- if (omitted_side == "A") p$strategy_a else p$strategy_b
        strategy_run_ids <- unique(selected_queries[["run_id"]][selected_queries[["strategy"]] == omitted_strategy])
        run_positions <- which(rr[["run_id"]] %in% strategy_run_ids)
        chronological_run_ids <- rr[["run_id"]][run_positions]
        assert(length(chronological_run_ids) == 5L, "Whole-run omission requires five distinct actual runs per strategy")
        for (omitted_run in chronological_run_ids) {
          remaining_positions <- which(selected_queries[["run_id"]] != omitted_run)
          remaining_queries <- selected_queries[remaining_positions]
          scenario_pairs <- pair_questions(remaining_queries, p$benchmark, p$strategy_a, p$strategy_b,
            p$metric, excluded_query = excluded_question, summary = FALSE)
          assert(nrow(scenario_pairs) == expected_questions,
                 "Whole-run omission changed the matched reference question set")
          expected_a_repeats <- if (omitted_side == "A") 4L else 5L
          expected_b_repeats <- if (omitted_side == "B") 4L else 5L
          assert(all(scenario_pairs[["n_valid_a"]] == expected_a_repeats) &&
                   all(scenario_pairs[["n_valid_b"]] == expected_b_repeats),
                 "Whole-run omission did not retain all five runs on the other side")
          result_row <- sensitivity_row(scenario_pairs, reference, spec$comparison_id, p$comparison_id,
            variant, paste0("omit_", omitted_side, "_", omitted_run), omitted_side, omitted_run,
            if (is.null(excluded_question)) "" else excluded_question)
          result_row[, reference_policy := if (is.null(excluded_question)) "all_questions_all_runs" else
            "same_199_questions_all_runs;both_sides_query3030_excluded_before_run_omission"]
          rows[[length(rows) + 1L]] <- result_row
        }
      }
    } else {
      excluded_question <- if (variant %in% c("exclude_query3030", "left_hold_exclude_query3030")) "3030" else NULL
      sensitivity_metric <- if (variant %in% c("left_hold", "left_hold_exclude_query3030")) "gpu_left_j" else p$metric
      scenario_pairs <- pair_questions(s, p$benchmark, p$strategy_a, p$strategy_b,
        sensitivity_metric, excluded_query = excluded_question)
      assert(nrow(scenario_pairs) == if (is.null(excluded_question)) 200L else 199L,
             "Sensitivity question count differs from the approved rule")
      result_row <- sensitivity_row(scenario_pairs, base_pairs, spec$comparison_id, p$comparison_id,
        variant, variant, excluded_query = if (is.null(excluded_question)) "" else excluded_question)
      result_row[, reference_policy := "primary_trapezoid_or_cpu_all_200_questions_including_approved_four_repeat_mean"]
      rows[[length(rows) + 1L]] <- result_row
    }
  }
  sensitivity <- data.table::rbindlist(rows, fill = TRUE)
  metadata <- primary[, .(parent_comparison_id = comparison_id, benchmark, strategy_a, strategy_b, metric)]
  sensitivity <- merge(sensitivity, metadata, by = "parent_comparison_id", sort = FALSE)
  sensitivity[, unit := ifelse(metric == "latency_s", "s/query", "J/query")]
  assert(nrow(sensitivity) == 420L && data.table::uniqueN(sensitivity[["specification_id"]]) == 60L &&
    !anyDuplicated(sensitivity[, .(specification_id, scenario)]), "Expanded sensitivity output is not 420 unique scenarios from 60 specifications")
  scenario_counts <- sensitivity[, .N, by = analysis_variant]
  expected_counts <- c(left_hold = 14L, exclude_query3030 = 4L,
    left_hold_exclude_query3030 = 2L, whole_run_omission_collection = 400L)
  assert(all(scenario_counts[["N"]] == unname(expected_counts[scenario_counts[["analysis_variant"]]])),
         "Expanded sensitivity scenario counts differ from 14/4/2/400")
  hashes_after <- unname(vapply(sources, hash, character(1)))
  assert(identical(hashes_before, hashes_after), "Sensitivity source or processing input changed during computation")
  assert(dir.create(out, recursive = FALSE), "Could not create fresh sensitivity output directory")
  output_path <- file.path(out, "sensitivity_point_estimates.csv")
  data.table::fwrite(sensitivity, output_path, na = "NA", bom = FALSE)
  data.table::fwrite(source_records, file.path(out, "source_hashes.csv"))
  data.table::fwrite(scenario_counts, file.path(out, "scenario_counts.csv"))
  jsonlite::write_json(list(status = "pass", stage = "approved_sensitivity_point_estimates_only",
    specifications = 60L, scenarios = 420L, whole_run_scenarios = 400L,
    generated_from_new_processing = processing_dir,
    static_specification = static_plan_path,
    reused_helpers = c("diag_pair", "diag_metric_values", "diag_sensitivity", "diag_assert"),
    historical_numeric_sensitivity_output_read = FALSE, complete_diagnostics_executed = FALSE,
    historical_tests_executed = FALSE, inference_executed = FALSE,
    source_input_hashes_unchanged = TRUE, output_sha256 = hash(output_path),
    relative_change_rule = "abs(reference)>max(1e-8,0.01*mean((abs(A)+abs(B))/2))",
    mmlu_small_energy_run_omission_rule = "exclude_query3030_both_sides;199_question_all_run_reference;omit_one_actual_run_on_one_side_only",
    created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
    file.path(out, "provenance.json"), auto_unbox = TRUE, pretty = TRUE)
  readme <- c("# 敏感性点估计复现 / Sensitivity point-estimate reproduction", "",
    "## 来源与执行 / Sources and execution", "",
    "中文：本阶段从本轮新生成的query_metrics.csv、question_summary.csv和run_reconciliation.csv重新计算60个既定敏感性规范，展开420条点估计。静态比较清单来自analysis/descriptive_20261017/planned_comparisons.csv。只在隔离环境载入旧模块的纯函数定义，调用配对和点估计函数；没有读取或复制旧420条数值，没有执行完整诊断、旧测试或正式推断。", "",
    "English: This stage recalculates the 60 fixed sensitivity specifications as 420 point estimates from this reproduction run's newly generated query_metrics.csv, question_summary.csv and run_reconciliation.csv. The static specification is analysis/descriptive_20261017/planned_comparisons.csv. Historical pure functions are loaded into an isolated environment for pairing and point estimation only. No historical 420-row numeric output is read or copied, and full diagnostics, historical tests and formal inference are not executed.", "",
    "## 不变规则 / Retained rules", "",
    "中文：14条左端保持、4条双方排除query3030、2条结合以及400条单边留一整run场景均保留。涉及MMLU small_only能耗的留一run始终使用双方排除query3030后的相同199题参考；每次仅省略A或B一个真实run，不按同rep同时删两方。延迟使用原latency_ms/1000秒。近零参考值的相对变化按既定规则标为不适用，原单位变化始终保留。", "",
    "English: The output retains 14 left-hold scenarios, four bilateral query3030 exclusions, two combined scenarios and 400 one-sided whole-run omissions. MMLU small_only energy omissions always use the same 199-question all-run reference after excluding query3030 from both sides. Each scenario omits one actual run from A or B, never both sides with a matching repetition label. Latency uses original latency_ms/1000 seconds. Relative changes near a zero reference follow the established not-applicable rule while original-unit changes are retained.", "",
    "## 记录 / Records", "",
    "中文：source_hashes.csv记录新输入、旧纯函数模块、静态清单和本适配代码的SHA-256；provenance.json记录执行范围与保护核验。所有已有文件保持只读，输出目录必须不存在。该表仅含敏感性点估计，不含p值、推断区间或标准化效应量。", "",
    "English: source_hashes.csv records SHA-256 for the new inputs, historical pure-function module, static specification and this adapter; provenance.json records scope and unchanged-input verification. Existing files remain read-only and the output directory must not exist. The table contains sensitivity point estimates only, without p-values, inferential intervals or standardized effects.")
  writeLines(enc2utf8(readme), file.path(out, "README.md"), useBytes = TRUE)
  invisible(list(output_dir = out, sensitivity = sensitivity,
                 specifications = 60L, scenarios = 420L, source_hashes = source_records))
}
