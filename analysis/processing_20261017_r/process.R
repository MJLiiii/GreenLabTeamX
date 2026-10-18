# Native R, read-only-input processing. No experiment modules are imported.
# User-approved Time integration and missing-tail rules, 2026-10-17.

prepare_energy <- function(raw, allow_initial_duplicate = FALSE) {
  raw <- as.data.frame(raw, check.names = FALSE)
  needed <- c("Time", "CPU_ENERGY (J)", "GPU0_POWER (mWatts)", "GPU1_POWER (mWatts)")
  if (!all(needed %in% names(raw))) stop("Required energy columns missing")
  if (nrow(raw) < 2L) stop("At least two energy records required")
  num <- function(x) suppressWarnings(as.numeric(x))
  d <- data.frame(Time = num(raw$Time),
                  gpu_power_mw = num(raw[[needed[3]]]) + num(raw[[needed[4]]]),
                  gpu0_power_mw = num(raw[[needed[3]]]), gpu1_power_mw = num(raw[[needed[4]]]),
                  CPU_ENERGY = num(raw[[needed[2]]]),
                  source_record_index = seq_len(nrow(raw)))
  duplicate <- is.finite(d$Time[1]) && is.finite(d$Time[2]) && d$Time[1] == d$Time[2]
  remove <- duplicate && isTRUE(allow_initial_duplicate)
  init <- data.frame(first_time_ms = d$Time[1], second_time_ms = d$Time[2],
                     initial_interval_ms = d$Time[2] - d$Time[1],
                     first_cpu_j = d$CPU_ENERGY[1], second_cpu_j = d$CPU_ENERGY[2],
                     initial_cpu_increment_j = d$CPU_ENERGY[2] - d$CPU_ENERGY[1],
                     excluded_cpu_initialization_j = if (remove) d$CPU_ENERGY[2] - d$CPU_ENERGY[1] else 0,
                     initial_duplicate_removed = remove,
                     removed_source_record_index = if (remove) 1L else NA_integer_,
                     retained_source_record_index = if (remove) 2L else 1L)
  problems <- character()
  if (duplicate && !allow_initial_duplicate) problems <- c(problems, "unapproved_initial_duplicate")
  if (!duplicate && allow_initial_duplicate) problems <- c(problems, "expected_initial_duplicate_absent")
  if (remove) d <- d[-1L, , drop = FALSE]
  time_valid <- all(is.finite(d$Time)) && all(diff(d$Time) > 0)
  if (!time_valid) problems <- c(problems, "nonincreasing_or_nonfinite_time")
  original_gpu <- c(num(raw[[needed[3]]]), num(raw[[needed[4]]]))
  if (any(!is.finite(original_gpu) | original_gpu < 0)) problems <- c(problems, "gpu_invalid_power")
  if (!is.finite(init$initial_cpu_increment_j) || init$initial_cpu_increment_j < 0) problems <- c(problems, "cpu_initialization_anomaly")
  if (any(!is.finite(d$CPU_ENERGY) | d$CPU_ENERGY < 0) || any(diff(d$CPU_ENERGY) < 0, na.rm = TRUE)) {
    problems <- c(problems, "cpu_counter_anomaly")
  }
  list(data = d, init = init, problems = unique(problems), time_valid = time_valid)
}

integrate_window <- function(view, start_ms, end_ms, keep_segments = TRUE) {
  d <- if (is.list(view) && "data" %in% names(view)) view$data else view
  blank <- list(gpu_trapezoid_j = NA_real_, gpu_left_j = NA_real_, cpu_j = NA_real_,
                covered_gpu_trapezoid_j = NA_real_, covered_gpu_left_j = NA_real_, covered_cpu_j = NA_real_,
                coverage_complete = FALSE, missing_start_ms = NA_real_, missing_end_ms = NA_real_,
                covered_start_ms = NA_real_, covered_end_ms = NA_real_, covered_duration_ms = NA_real_,
                start_bracket_ms = NA_real_, end_bracket_ms = NA_real_,
                first_source_record_index = NA_integer_, last_source_record_index = NA_integer_,
                cpu_anomaly = FALSE, gpu_anomaly = FALSE, segments = data.frame())
  if (!all(is.finite(c(start_ms, end_ms))) || end_ms < start_ms) stop("Invalid integration window")
  if (nrow(d) < 2L || any(!is.finite(d$Time)) || any(diff(d$Time) <= 0)) return(blank)
  t <- d$Time
  a <- max(start_ms, t[1]); b <- min(end_ms, tail(t, 1))
  blank$missing_start_ms <- max(0, min(end_ms, t[1]) - start_ms)
  blank$missing_end_ms <- max(0, end_ms - max(start_ms, tail(t, 1)))
  blank$covered_start_ms <- a; blank$covered_end_ms <- max(a, b)
  blank$covered_duration_ms <- max(0, b - a)
  blank$coverage_complete <- start_ms >= t[1] && end_ms <= tail(t, 1)
  if (b < a) return(blank)
  if (b == a) {
    blank$covered_gpu_trapezoid_j <- blank$covered_gpu_left_j <- blank$covered_cpu_j <- 0
    if (blank$coverage_complete) blank$gpu_trapezoid_j <- blank$gpu_left_j <- blank$cpu_j <- 0
    return(blank)
  }
  il <- min(length(t) - 1L, max(1L, findInterval(a, t)))
  ir <- min(length(t) - 1L, max(1L, findInterval(b, t)))
  idx <- seq.int(il, ir)
  left <- pmax(a, t[idx]); right <- pmin(b, t[idx + 1L])
  keep <- right > left
  idx <- idx[keep]; left <- left[keep]; right <- right[keep]
  interval <- t[idx + 1L] - t[idx]
  fraction_a <- (left - t[idx]) / interval
  fraction_b <- (right - t[idx]) / interval
  p0 <- d$gpu_power_mw[idx]; p1 <- d$gpu_power_mw[idx + 1L]
  pa <- p0 + (p1 - p0) * fraction_a; pb <- p0 + (p1 - p0) * fraction_b
  c0 <- d$CPU_ENERGY[idx]; c1 <- d$CPU_ENERGY[idx + 1L]
  ca <- c0 + (c1 - c0) * fraction_a; cb <- c0 + (c1 - c0) * fraction_b
  gpu_ok <- is.finite(p0) & is.finite(p1) & p0 >= 0 & p1 >= 0
  for (gpu in intersect(c("gpu0_power_mw", "gpu1_power_mw"), names(d))) {
    gx <- d[[gpu]]
    gpu_ok <- gpu_ok & is.finite(gx[idx]) & is.finite(gx[idx + 1L]) & gx[idx] >= 0 & gx[idx + 1L] >= 0
  }
  cpu_ok <- is.finite(c0) & is.finite(c1) & c0 >= 0 & c1 >= c0
  trap <- (pa + pb) / 2 * (right - left) / 1e6
  step <- p0 * (right - left) / 1e6
  cpu <- cb - ca
  trap[!gpu_ok] <- NA_real_; step[!gpu_ok] <- NA_real_; cpu[!cpu_ok] <- NA_real_
  blank$gpu_anomaly <- any(!gpu_ok); blank$cpu_anomaly <- any(!cpu_ok)
  blank$covered_gpu_trapezoid_j <- sum(trap)
  blank$covered_gpu_left_j <- sum(step)
  # Endpoint subtraction is the specified estimator. Segment sum is evidence only.
  blank$covered_cpu_j <- if (all(cpu_ok)) tail(cb, 1) - ca[1] else NA_real_
  blank$start_bracket_ms <- interval[1]
  blank$end_bracket_ms <- tail(interval, 1)
  blank$first_source_record_index <- d$source_record_index[idx[1]]
  blank$last_source_record_index <- d$source_record_index[tail(idx, 1) + 1L]
  if (blank$coverage_complete) {
    blank$gpu_trapezoid_j <- blank$covered_gpu_trapezoid_j
    blank$gpu_left_j <- blank$covered_gpu_left_j
    blank$cpu_j <- blank$covered_cpu_j
  }
  if (keep_segments) blank$segments <- data.frame(
    left_source_record_index = d$source_record_index[idx],
    right_source_record_index = d$source_record_index[idx + 1L],
    sample_left_ms = t[idx], sample_right_ms = t[idx + 1L],
    clipped_left_ms = left, clipped_right_ms = right, duration_ms = right - left,
    sample_left_gpu_power_mw = p0, sample_right_gpu_power_mw = p1,
    clipped_left_gpu_power_mw = pa, clipped_right_gpu_power_mw = pb,
    sample_left_cpu_j = c0, sample_right_cpu_j = c1,
    clipped_left_cpu_j = ca, clipped_right_cpu_j = cb,
    gpu_trapezoid_j = trap, gpu_left_j = step, cpu_increment_j = cpu,
    gpu_segment_valid = gpu_ok, cpu_segment_valid = cpu_ok)
  blank
}

summarize_metric <- function(x) {
  x <- as.numeric(x); x <- x[is.finite(x)]; n <- length(x)
  list(n_valid = n, mean = if (n) mean(x) else NA_real_, sd = if (n > 1) stats::sd(x) else NA_real_,
       min = if (n) min(x) else NA_real_, max = if (n) max(x) else NA_real_,
       range = if (n) max(x) - min(x) else NA_real_)
}

majority_correct <- function(x) {
  x <- as.numeric(x); valid <- is.finite(x) & x %in% c(0, 1)
  list(n_valid = sum(valid), sum_correct = sum(x[valid]),
       mean_correct = if (any(valid)) mean(x[valid]) else NA_real_,
       majority_correct = if (length(x) == 5L && all(valid)) sum(x) >= 3 else NA,
       disagreement = if (any(valid)) length(unique(x[valid])) > 1L else NA)
}

process_all <- function(root, out) {
  stopifnot(dir.exists(root), dir.exists(out))
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  out <- normalizePath(out, winslash = "/", mustWork = TRUE)
  if (!startsWith(out, paste0(root, "/analysis/"))) stop("Output must be under analysis/")
  abs_tol <- 1e-6; rel_tol <- 1e-10
  source_rows <- list(); issue_rows <- list()
  read_source <- function(rel, format = "csv", character = FALSE) {
    path <- file.path(root, rel)
    if (!file.exists(path)) stop("Missing input: ", rel)
    sha <- digest::digest(file = path, algo = "sha256")
    if (format == "json") obj <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    else obj <- data.table::fread(path, check.names = FALSE, integer64 = "double", encoding = "UTF-8",
                                 colClasses = if (character) "character" else NULL, na.strings = NULL)
    source_rows[[length(source_rows) + 1L]] <<- data.frame(path = rel, sha256 = sha,
      bytes = file.info(path)$size, records = if (format == "csv") nrow(obj) else NA_integer_, format = format)
    attr(obj, "source_sha256") <- sha
    obj
  }
  write_new <- function(x, name) {
    path <- file.path(out, name)
    if (file.exists(path)) stop("Refusing existing output: ", path)
    data.table::fwrite(x, path, na = "NA", bom = FALSE, logical01 = FALSE, quote = "auto")
  }
  issue <- function(run, query, code, detail) {
    issue_rows[[length(issue_rows) + 1L]] <<- data.frame(run_id = run, query_id = query,
      issue_code = code, detail = detail, stringsAsFactors = FALSE)
  }
  number <- function(x) suppressWarnings(as.numeric(x))
  boolean <- function(x) ifelse(tolower(as.character(x)) == "true", 1,
                                ifelse(tolower(as.character(x)) == "false", 0, NA_real_))
  scalar <- function(x) if (is.null(x) || !length(x)) NA_real_ else as.numeric(x[[1]])
  good_sum <- function(x) if (any(!is.finite(x))) NA_real_ else sum(x)
  tolerance <- function(total) abs_tol + rel_tol * abs(total)
  relative <- function(a, b) ifelse(is.finite(b) & b != 0, 100 * (a - b) / b, NA_real_)
  mf <- read_source("results/main/manifest.csv", character = TRUE)
  val <- read_source("analysis/validation/audit_20261017/run_validation.csv", character = TRUE)
  expected_dup <- val$run_id[number(val$duplicate_time) == 1]
  if (length(expected_dup) != 48L) stop("Validation duplicate registry no longer has 48 entries")
  if (anyDuplicated(mf$run_id)) stop("Duplicate manifest run_id prevents unambiguous join")
  query_rows <- list(); run_rows <- list(); idle_rows <- list(); resource_rows <- list()
  init_rows <- list(); init_samples <- list(); case_rows <- list(); case_segments <- list(); case_calls <- list()
  selected_cases <- character(); benchmark_query_sets <- list()
  for (ri in seq_len(nrow(mf))) {
    m <- mf[ri]; run_id <- m$run_id; message("Processing ", ri, "/", nrow(mf), ": ", run_id)
    dir <- paste0("results/main/", run_id)
    if (!m$kind %in% c("run", "idle") || m$status != "done" || !identical(number(m$exit_code), 0)) {
      issue(run_id, NA_character_, "manifest_state_unexpected", paste(m$kind, m$status, m$exit_code))
    }
    if (gsub("\\\\", "/", m$run_dir) != dir) issue(run_id, NA_character_, "manifest_run_dir_mismatch", m$run_dir)
    raw <- read_source(paste0(dir, "/energy.csv")); energy_sha <- attr(raw, "source_sha256")
    historical <- read_source(paste0(dir, "/summary.json"), "json")
    raw_n <- nrow(raw)
    view <- prepare_energy(raw, run_id %in% expected_dup)
    real_initial_intervals <- c(`001` = 3, `003` = 2, `004` = 2, `024` = 1, `032` = 1, `044` = 1, `046` = 1)
    prefix <- substr(run_id, 1, 3)
    if (prefix %in% names(real_initial_intervals) && !isTRUE(view$init$initial_interval_ms == real_initial_intervals[[prefix]])) {
      issue(run_id, NA_character_, "genuine_initial_interval_changed", as.character(view$init$initial_interval_ms))
    }
    if (length(view$problems)) for (p in view$problems) issue(run_id, NA_character_, p, "Input anomaly retained; affected metric unavailable")
    irow <- cbind(data.frame(run_id = run_id, kind = m$kind, energy_source = paste0(dir, "/energy.csv"),
                            energy_sha256 = energy_sha), view$init)
    init_rows[[ri]] <- irow
    first_two <- data.table::copy(raw[1:2])
    first_two[, `:=`(run_id = run_id, source_record_index = 1:2, source_csv_line_number = 2:3,
                    energy_source = paste0(dir, "/energy.csv"), energy_sha256 = energy_sha)]
    init_samples[[ri]] <- first_two
    t0 <- view$data$Time[1]; t1 <- tail(view$data$Time, 1)
    total <- integrate_window(view, t0, t1, FALSE)
    p_raw <- number(raw[["GPU0_POWER (mWatts)"]]) + number(raw[["GPU1_POWER (mWatts)"]])
    legacy_gpu <- good_sum(p_raw * number(raw$Delta) / 1e6)
    legacy_cpu <- tail(number(raw[["CPU_ENERGY (J)"]]), 1) - number(raw[["CPU_ENERGY (J)"]])[1]
    gpu_cols <- grep("^GPU[0-9]+_USAGE$", names(raw), value = TRUE)
    cpu_cols <- grep("^CPU_USAGE_[0-9]+$", names(raw), value = TRUE)
    mem_cols <- grep("^GPU[0-9]+_MEMORY_USED$", names(raw), value = TRUE)
    resources <- data.frame(run_id = run_id, kind = m$kind, benchmark = m$benchmark,
      strategy = m$router, repetition = number(m$repetition), resource_level = "run",
      source_energy_path = paste0(dir, "/energy.csv"), source_energy_sha256 = energy_sha,
      raw_energy_samples = raw_n,
      mean_gpu_utilization_pct = if (length(gpu_cols)) mean(rowMeans(as.matrix(raw[, ..gpu_cols]))) else NA_real_,
      mean_cpu_utilization_pct = if (length(cpu_cols)) mean(rowMeans(as.matrix(raw[, ..cpu_cols]))) else NA_real_,
      peak_single_gpu_memory_mib = if (length(mem_cols)) max(as.matrix(raw[, ..mem_cols])) else NA_real_,
      peak_system_memory_bytes = if ("USED_MEMORY" %in% names(raw)) max(raw$USED_MEMORY) else NA_real_,
      aggregation = "equal_weight_raw_samples_and_devices; maximum_single_device_memory")
    resource_rows[[ri]] <- resources
    q_ints <- list(); gaps <- list(); queries <- NULL; n_queries <- 0L; n_calls <- 0L
    pre <- integrate_window(view, t0, t0, FALSE); post <- pre
    idle_window <- pre
    first_query <- last_query <- NA_real_
    if (m$kind == "run") {
      runmeta <- read_source(paste0(dir, "/run.json"), "json")
      queries <- read_source(paste0(dir, "/queries.csv"), character = TRUE); qsha <- attr(queries, "source_sha256")
      calls <- read_source(paste0(dir, "/calls.csv"), character = TRUE); csha <- attr(calls, "source_sha256")
      calls[, source_call_record_index := seq_len(.N)]
      n_queries <- nrow(queries); n_calls <- nrow(calls)
      if (anyDuplicated(queries$query_id)) issue(run_id, NA_character_, "duplicate_query_id", "Rows retained; aggregation requires review")
      if (n_queries != 200L) issue(run_id, NA_character_, "unexpected_query_count", as.character(n_queries))
      observed_set <- sort(unique(queries$query_id))
      if (is.null(benchmark_query_sets[[m$benchmark]])) benchmark_query_sets[[m$benchmark]] <- observed_set
      else if (!identical(observed_set, benchmark_query_sets[[m$benchmark]])) {
        issue(run_id, NA_character_, "benchmark_question_set_mismatch", "Question sets differ across strategy or repetition; no records discarded")
      }
      starts <- number(queries$started_at_ms); ends <- number(queries$ended_at_ms)
      if (any(diff(starts) < 0) || any(head(ends, -1L) > tail(starts, -1L))) {
        issue(run_id, NA_character_, "query_order_or_overlap", "No automatic query sorting or overlap repair")
      }
      first_query <- starts[1]; last_query <- tail(ends, 1)
      pre <- integrate_window(view, t0, max(t0, min(t1, first_query)), FALSE)
      post <- integrate_window(view, min(t1, max(t0, last_query)), t1, FALSE)
      if (n_queries > 1L) for (j in seq_len(n_queries - 1L)) {
        ga <- min(t1, max(t0, ends[j])); gb <- min(t1, max(t0, starts[j + 1L]))
        if (gb >= ga) gaps[[j]] <- integrate_window(view, ga, gb, FALSE)
        else gaps[[j]] <- list(covered_gpu_trapezoid_j = NA_real_, covered_gpu_left_j = NA_real_, covered_cpu_j = NA_real_, covered_duration_ms = NA_real_)
      }
      for (qi in seq_len(n_queries)) {
        q <- queries[qi]; cs <- calls[query_id == q$query_id]
        integ <- integrate_window(view, starts[qi], ends[qi], FALSE); q_ints[[qi]] <- integ
        approved_tail <- identical(run_id, "012_small_only__mmlu_pro__rep4") && q$query_id == "3030"
        expected_tail <- approved_tail && integ$missing_start_ms == 0 && integ$missing_end_ms == 2
        if (!isTRUE(integ$coverage_complete) && !isTRUE(expected_tail)) {
          issue(run_id, q$query_id, "unexpected_coverage_missing", "Full energy NA; covered values retained without extrapolation")
        }
        if (approved_tail && !isTRUE(expected_tail)) issue(run_id, q$query_id, "approved_tail_changed", "Historical 2 ms tail differs from current input")
        if (approved_tail) integ$gpu_trapezoid_j <- integ$gpu_left_j <- integ$cpu_j <- NA_real_
        contained <- nrow(cs) > 0 && all(number(cs$started_at_ms) >= starts[qi] & number(cs$ended_at_ms) <= ends[qi])
        gen <- cs[kind == "generate"]; emb <- cs[kind == "embed"]
        embed_tokens <- number(emb$prompt_tokens)
        embed_token_n_available <- sum(is.finite(embed_tokens))
        embed_token_sum <- if (!nrow(emb)) 0 else if (all(is.finite(embed_tokens))) sum(embed_tokens) else NA_real_
        gen_prompt <- number(gen$prompt_tokens); gen_completion <- number(gen$completion_tokens)
        token_link_ok <- all(is.finite(gen_prompt)) && all(is.finite(gen_completion)) &&
          sum(gen_prompt) == number(q$prompt_tokens_total) && sum(gen_completion) == number(q$completion_tokens_total)
        link_ok <- nrow(gen) == number(q$num_generate_calls) && all(cs$run_id == run_id) && q$run_id == run_id &&
          q$benchmark == m$benchmark && q$router == m$router && contained
        if (!isTRUE(link_ok)) issue(run_id, q$query_id, "call_link_mismatch", "Original records retained; inspect call/query association")
        if (!isTRUE(token_link_ok)) issue(run_id, q$query_id, "generate_token_mismatch", "Original query totals differ from associated generate call totals")
        if (embed_token_n_available < nrow(emb)) issue(run_id, q$query_id, "embedding_token_missing", "Embedding token total NA because one or more call values are unavailable")
        quality <- if (isTRUE(expected_tail)) "approved_missing_tail_2ms" else if (!isTRUE(integ$coverage_complete)) "unexpected_missing_coverage" else "complete"
        if (integ$cpu_anomaly || integ$gpu_anomaly) quality <- paste(quality, "sensor_anomaly", sep = ";")
        derived <- data.table::data.table(strategy = m$router, repetition = number(m$repetition),
          source_query_path = paste0(dir, "/queries.csv"), source_query_record_index = qi, source_query_sha256 = qsha,
          source_call_path = paste0(dir, "/calls.csv"), source_call_record_indices = paste(cs$source_call_record_index, collapse = ";"), source_call_sha256 = csha,
          source_energy_path = paste0(dir, "/energy.csv"), source_energy_sha256 = energy_sha,
          source_manifest_record_index = ri, source_manifest_sha256 = attr(mf, "source_sha256"),
          settings_fingerprint = runmeta$settings_fingerprint,
          source_energy_first_record_index = integ$first_source_record_index, source_energy_last_record_index = integ$last_source_record_index,
          sampling_start_ms = t0, sampling_end_ms = t1, covered_start_ms = integ$covered_start_ms, covered_end_ms = integ$covered_end_ms,
          wall_duration_ms = ends[qi] - starts[qi], covered_duration_ms = integ$covered_duration_ms,
          missing_start_ms = integ$missing_start_ms, missing_end_ms = integ$missing_end_ms,
          start_bracket_ms = integ$start_bracket_ms, end_bracket_ms = integ$end_bracket_ms,
          coverage_complete = integ$coverage_complete, coverage_status = quality,
          gpu_trapezoid_j = integ$gpu_trapezoid_j, gpu_left_j = integ$gpu_left_j, cpu_j = integ$cpu_j,
          covered_gpu_trapezoid_j = integ$covered_gpu_trapezoid_j, covered_gpu_left_j = integ$covered_gpu_left_j, covered_cpu_j = integ$covered_cpu_j,
          gpu_left_minus_trapezoid_j = integ$gpu_left_j - integ$gpu_trapezoid_j,
          gpu_left_vs_trapezoid_pct = relative(integ$gpu_left_j, integ$gpu_trapezoid_j),
          correct_numeric = boolean(q$correct),
          call_count = nrow(cs), generate_call_count_observed = nrow(gen), embedding_call_count = nrow(emb),
          embedding_prompt_tokens = embed_token_sum, embedding_prompt_tokens_n_available = embed_token_n_available,
          generate_tokens_link_verified = token_link_ok,
          call_query_link_verified = link_ok, all_calls_inside_query = contained,
          call_models_all = paste(cs$model, collapse = ";"),
          call_latency_sum_s = sum(number(cs$latency_s)),
          query_minus_call_latency_ms = number(q$latency_ms) - 1000 * sum(number(cs$latency_s)),
          gpu_method = "time_linear_trapezoid_two_gpu_sum", gpu_sensitivity_method = "time_original_interval_left_hold",
          cpu_method = "time_linear_counter_boundary_difference", energy_scope = "gross_complete_router_query",
          energy_sensitivity_exclude_question = approved_tail, initialization_removed_from_view = view$init$initial_duplicate_removed)
        query_rows[[length(query_rows) + 1L]] <- cbind(q, derived)
        case_type <- if (approved_tail) "missing_tail" else if (m$router == "small_only" && !"fixed" %in% selected_cases) "fixed" else if (m$router == "cascade" && nrow(gen) > 1 && !"cascade" %in% selected_cases) "cascade" else if (m$router == "matrix_factorization" && !"mf" %in% selected_cases) "mf" else NA_character_
        if (!is.na(case_type) && !case_type %in% selected_cases) {
          selected_cases <- c(selected_cases, case_type)
          detail <- integrate_window(view, starts[qi], ends[qi], TRUE)
          ss <- data.table::as.data.table(detail$segments)
          ss[, `:=`(case_type = case_type, run_id = run_id, query_id = q$query_id,
                    energy_source = paste0(dir, "/energy.csv"), energy_sha256 = energy_sha)]
          case_segments[[length(case_segments) + 1L]] <- ss
          cc <- data.table::copy(cs); cc[, `:=`(case_type = case_type, source_call_path = paste0(dir, "/calls.csv"), source_call_sha256 = csha)]
          case_calls[[length(case_calls) + 1L]] <- cc
          case_rows[[length(case_rows) + 1L]] <- cbind(data.table::data.table(case_type = case_type), q, derived)
        }
      }
    } else if (m$kind == "idle") {
      idle_window <- total
      idle_rows[[length(idle_rows) + 1L]] <- data.frame(run_id = run_id, repetition = number(m$repetition),
        sampling_start_ms = t0, sampling_end_ms = t1, effective_duration_s = (t1 - t0) / 1000,
        gpu_trapezoid_j = total$gpu_trapezoid_j, gpu_left_j = total$gpu_left_j, cpu_j = total$cpu_j,
        mean_gpu_trapezoid_w = total$gpu_trapezoid_j / ((t1 - t0) / 1000),
        mean_gpu_left_w = total$gpu_left_j / ((t1 - t0) / 1000), mean_cpu_w = total$cpu_j / ((t1 - t0) / 1000),
        raw_samples = raw_n, derived_samples = nrow(view$data), initial_duplicate_removed = view$init$initial_duplicate_removed,
        excluded_cpu_initialization_j = view$init$excluded_cpu_initialization_j,
        initial_cpu_increment_diagnostic_j = view$init$initial_cpu_increment_j,
        energy_scope = "gross_idle_derived_sampling_window", source_energy_path = paste0(dir, "/energy.csv"), source_energy_sha256 = energy_sha,
        resident_ok_before_recorded = m$resident_ok_before, resident_ok_after_recorded = m$resident_ok_after)
    } else issue(run_id, NA_character_, "unknown_run_kind", m$kind)
    sum_components <- function(items, field) if (!length(items)) 0 else good_sum(vapply(items, function(x) x[[field]], numeric(1)))
    rr <- list(run_id = run_id, kind = m$kind, benchmark = m$benchmark, strategy = m$router, repetition = number(m$repetition),
      manifest_status = m$status, manifest_exit_code = number(m$exit_code),
      process_start_ms = number(m$started_at_ms), process_end_ms = number(m$ended_at_ms),
      process_duration_ms = number(m$ended_at_ms) - number(m$started_at_ms),
      sampling_start_ms = t0, sampling_end_ms = t1, sampling_duration_ms = t1 - t0,
      task_first_query_ms = first_query, task_last_query_ms = last_query,
      n_queries = n_queries, n_calls = n_calls, raw_energy_samples = raw_n, derived_energy_samples = nrow(view$data),
      initial_duplicate_removed = view$init$initial_duplicate_removed,
      initial_interval_ms = view$init$initial_interval_ms, initial_cpu_increment_diagnostic_j = view$init$initial_cpu_increment_j,
      excluded_cpu_initialization_j = view$init$excluded_cpu_initialization_j,
      covered_query_duration_ms = sum_components(q_ints, "covered_duration_ms"),
      gap_duration_ms = sum_components(gaps, "covered_duration_ms"),
      pre_query_duration_ms = pre$covered_duration_ms, post_query_duration_ms = post$covered_duration_ms,
      idle_duration_ms = idle_window$covered_duration_ms,
      missing_query_start_ms = sum_components(q_ints, "missing_start_ms"), missing_query_end_ms = sum_components(q_ints, "missing_end_ms"),
      source_energy_path = paste0(dir, "/energy.csv"), source_energy_sha256 = energy_sha,
      source_summary_path = paste0(dir, "/summary.json"), source_summary_sha256 = attr(historical, "source_sha256"))
    for (metric in c("gpu_trapezoid", "gpu_left", "cpu")) {
      field <- paste0("covered_", metric, "_j")
      a <- sum_components(q_ints, field); b <- sum_components(gaps, field)
      c <- pre[[field]]; d <- post[[field]]; idle <- idle_window[[field]]; whole <- total[[field]]
      rr[[paste0(metric, "_covered_queries_j")]] <- a
      rr[[paste0(metric, "_gaps_j")]] <- b
      rr[[paste0(metric, "_pre_query_j")]] <- c
      rr[[paste0(metric, "_post_query_j")]] <- d
      rr[[paste0(metric, "_idle_j")]] <- idle
      rr[[paste0(metric, "_window_j")]] <- whole
      rr[[paste0(metric, "_reconciliation_error_j")]] <- a + b + c + d + idle - whole
      rr[[paste0(metric, "_tolerance_j")]] <- tolerance(whole)
      rr[[paste0(metric, "_reconciliation_pass")]] <- is.finite(a + b + c + d + idle - whole) && abs(a + b + c + d + idle - whole) <= tolerance(whole)
    }
    rr$duration_reconciliation_error_ms <- rr$covered_query_duration_ms + rr$gap_duration_ms + rr$pre_query_duration_ms + rr$post_query_duration_ms + rr$idle_duration_ms - rr$sampling_duration_ms
    rr$legacy_delta_gpu_j <- legacy_gpu
    rr$historical_summary_gpu_j <- scalar(historical$total_gpu_joules)
    rr$legacy_gpu_minus_summary_j <- legacy_gpu - rr$historical_summary_gpu_j
    rr$legacy_cpu_endpoint_j <- legacy_cpu
    rr$historical_summary_cpu_j <- scalar(historical$total_cpu_joules)
    rr$legacy_cpu_minus_summary_j <- legacy_cpu - rr$historical_summary_cpu_j
    rr$historical_energibridge_summary_cpu_j <- scalar(historical$cpu_summary_joules)
    rr$cpu_legacy_minus_derived_and_initialization_j <- legacy_cpu - total$cpu_j - view$init$excluded_cpu_initialization_j
    rr$gpu_trapezoid_minus_legacy_delta_j <- total$gpu_trapezoid_j - legacy_gpu
    rr$gpu_trapezoid_vs_legacy_delta_pct <- relative(total$gpu_trapezoid_j, legacy_gpu)
    rr$gpu_left_minus_trapezoid_j <- total$gpu_left_j - total$gpu_trapezoid_j
    rr$gpu_left_vs_trapezoid_pct <- relative(total$gpu_left_j, total$gpu_trapezoid_j)
    rr$input_problem_count <- length(view$problems)
    run_rows[[ri]] <- data.table::as.data.table(rr)
  }
  qm <- data.table::rbindlist(query_rows, fill = TRUE)
  keys <- c("benchmark", "strategy", "repetition", "query_id")
  if (anyDuplicated(qm[, ..keys])) issue("ALL", NA_character_, "duplicate_query_strategy_repeat_key", "Rows retained; do not use summary without review")
  data.table::setorderv(qm, c("benchmark", "strategy", "query_id", "repetition"))
  qs <- qm[, {
    mc <- majority_correct(correct_numeric)
    ans <- list(n_repetitions = .N, repetitions = paste(repetition, collapse = ";"),
      run_ids = paste(run_id, collapse = ";"), correct_by_repetition = paste(correct_numeric, collapse = ";"),
      correct_n_valid = mc$n_valid, correct_sum = mc$sum_correct, mean_correct = mc$mean_correct,
      majority_correct = mc$majority_correct, correctness_disagreement = mc$disagreement,
      truncated_n = sum(tolower(truncated) == "true"), extraction_failed_n = sum(tolower(extraction_failed) == "true"),
      final_models = paste(final_model, collapse = ";"), call_counts = paste(call_count, collapse = ";"),
      energy_sensitivity_exclude_question = any(energy_sensitivity_exclude_question),
      summary_rule = "five_repeat_arithmetic_mean;sample_sd;majority_at_least_3_of_5")
    for (metric in c("gpu_trapezoid_j", "gpu_left_j", "cpu_j", "latency_ms", "routing_latency_s")) {
      s <- summarize_metric(.SD[[metric]])
      names(s) <- paste(metric, names(s), sep = "_")
      ans <- c(ans, s)
    }
    ans
  }, by = .(benchmark, strategy, query_id)]
  for (i in seq_len(nrow(qs))) {
    row <- qs[i]
    if (row$n_repetitions != 5L || row$repetitions != "1;2;3;4;5") issue("ALL", row$query_id, "repeat_set_mismatch", paste(row$benchmark, row$strategy, row$repetitions))
    if (row$correct_n_valid != 5L) issue("ALL", row$query_id, "correctness_repeat_missing", paste(row$benchmark, row$strategy, row$correct_n_valid))
    for (metric in c("latency_ms", "routing_latency_s")) {
      nv <- row[[paste0(metric, "_n_valid")]]
      if (nv != 5L) issue("ALL", row$query_id, "latency_repeat_missing", paste(row$benchmark, row$strategy, metric, nv))
    }
    for (metric in c("gpu_trapezoid_j", "gpu_left_j", "cpu_j")) {
      nv <- row[[paste0(metric, "_n_valid")]]
      allow4 <- row$benchmark == "mmlu_pro" && row$strategy == "small_only" && row$query_id == "3030" && nv == 4L
      if (nv != 5L && !allow4) issue("ALL", row$query_id, "unexpected_summary_missingness", paste(row$benchmark, row$strategy, metric, nv))
    }
  }
  runs <- data.table::rbindlist(run_rows, fill = TRUE)
  idle <- data.table::rbindlist(idle_rows, fill = TRUE)
  init <- data.table::rbindlist(init_rows, fill = TRUE)
  if (sum(init$initial_duplicate_removed) != 48L) issue("ALL", NA_character_, "initial_duplicate_count_changed", as.character(sum(init$initial_duplicate_removed)))
  if (sum(!init$initial_duplicate_removed) != 7L) issue("ALL", NA_character_, "genuine_initial_interval_count_changed", as.character(sum(!init$initial_duplicate_removed)))
  write_new(qm, "query_metrics.csv"); write_new(qs, "question_summary.csv")
  write_new(runs, "run_reconciliation.csv"); write_new(idle, "idle_summary.csv")
  write_new(data.table::rbindlist(resource_rows, fill = TRUE), "run_resources.csv")
  write_new(init, "initialization_records.csv"); write_new(data.table::rbindlist(init_samples, fill = TRUE), "initialization_samples.csv")
  write_new(data.table::rbindlist(case_rows, fill = TRUE), "example_queries.csv")
  write_new(data.table::rbindlist(case_segments, fill = TRUE), "example_segments.csv")
  write_new(data.table::rbindlist(case_calls, fill = TRUE), "example_calls.csv")
  sources <- unique(data.table::rbindlist(source_rows, fill = TRUE), by = "path")
  write_new(sources, "source_manifest.csv")
  issues <- if (length(issue_rows)) data.table::rbindlist(issue_rows, fill = TRUE) else data.table::data.table(run_id = character(), query_id = character(), issue_code = character(), detail = character())
  write_new(issues, "processing_issues.csv")
  list(query_metrics = qm, question_summary = qs, run_reconciliation = runs, idle_summary = idle,
       initialization = init, sources = sources, issues = issues,
       abs_tolerance_j = abs_tol, relative_tolerance = rel_tol)
}
