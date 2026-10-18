# Corrected point coordinates; historical figures.R remains read-only.
# Formal-inference graphics: render saved results only; do not calculate tests.
# All output files must be new. Explicit identifiers protect panel membership.

inference_plot_subset <- function(x, benchmark_key, metric_key, expected_ids) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  ids <- as.character(x$comparison_id)
  take <- as.character(x$benchmark) == benchmark_key &
    as.character(x$metric) == metric_key & ids %in% expected_ids
  z <- x[take, , drop = FALSE]
  if (anyDuplicated(z$comparison_id) || nrow(z) != length(expected_ids) ||
      !setequal(as.character(z$comparison_id), expected_ids)) {
    stop("Figure membership mismatch: ", benchmark_key, " / ", metric_key)
  }
  z[match(expected_ids, as.character(z$comparison_id)), , drop = FALSE]
}

inference_format_p <- function(x) {
  vapply(x, function(z) {
    if (!is.finite(z)) return("NA")
    if (z < 0 || z > 1) stop("Invalid p value supplied to figure")
    if (z == 0) return("< 2.23e-308*")
    if (z < 0.001) return(formatC(z, digits = 2L, format = "e"))
    formatC(z, digits = 3L, format = "f")
  }, character(1))
}

inference_reject_label <- function(x, status) {
  y <- as.character(x)
  ifelse(status != "ok" | is.na(x), "Unavailable",
         ifelse(tolower(y) %in% c("true", "1"), "Reject", "Do not reject"))
}

make_inference_figures <- function(out, figure_subdir = "figures", checks_filename = "figure_input_checks.csv") {
  if (!requireNamespace("data.table", quietly = TRUE)) stop("data.table is required")
  out <- normalizePath(out, winslash = "/", mustWork = TRUE)
  paths <- file.path(out, c("continuous_tests.csv", "accuracy_tests.csv",
                           "all_primary_tests.csv", "hac_sensitivity.csv"))
  if (!all(file.exists(paths))) stop("Saved inference tables are required before plotting")
  continuous <- as.data.frame(data.table::fread(paths[1L]))
  accuracy <- as.data.frame(data.table::fread(paths[2L]))
  primary <- as.data.frame(data.table::fread(paths[3L]))
  hac <- as.data.frame(data.table::fread(paths[4L]))
  require_fields <- function(d, fields, name) {
    absent <- setdiff(fields, names(d))
    if (length(absent)) stop(name, " lacks fields: ", paste(absent, collapse = ", "))
  }
  base_fields <- c("comparison_id", "rq", "benchmark", "metric", "strategy_a",
                   "strategy_b", "n_pairs", "mean_difference", "ci_low", "ci_high",
                   "p_holm", "reject_h0_holm", "status", "ci_multiplicity")
  require_fields(primary, base_fields, "all_primary_tests.csv")
  require_fields(hac, c("comparison_id", "benchmark", "metric", "lag", "se_ratio",
                       "reject_h0_holm", "status"), "hac_sensitivity.csv")
  stopifnot(nrow(continuous) == 40L, nrow(accuracy) == 14L, nrow(primary) == 54L,
            nrow(hac) == 120L, !anyDuplicated(primary$comparison_id),
            !anyDuplicated(paste(hac$comparison_id, hac$lag)),
            setequal(primary$comparison_id, c(continuous$comparison_id, accuracy$comparison_id)),
            setequal(hac$comparison_id, continuous$comparison_id),
            setequal(unique(hac$lag), c(5L, 10L, 20L)),
            all(primary$ci_multiplicity == "unadjusted_pointwise"))
  figure_dir <- file.path(out, figure_subdir)
  if (file.exists(figure_dir)) stop("Refusing to overwrite figures directory")
  dir.create(figure_dir, recursive = FALSE)
  benchmark_names <- c(mmlu_pro = "MMLU-Pro", gsm_hard = "GSM-Hard")
  metric_names <- c(gpu_trapezoid_j = "GPU gross energy", cpu_j = "CPU gross energy",
                    latency_s = "End-to-end latency", majority_correct = "Majority correctness")
  unit_names <- c(gpu_trapezoid_j = "J/query", cpu_j = "J/query",
                  latency_s = "s/query", majority_correct = "percentage points")
  strategy_names <- c(small_only = "Small", medium_only = "Medium", large_only = "Large",
                      cascade = "Cascade", matrix_factorization = "MF")
  strategy_colors <- c(small_only = "#0072B2", medium_only = "#56B4E9", large_only = "#D55E00",
                       cascade = "#009E73", matrix_factorization = "#CC79A7")
  lag_colors <- c(`5` = "#0072B2", `10` = "#E69F00", `20` = "#CC79A7")
  index <- list()
  checks <- list()
  tx <- function(label, x, y, size = 11, color = "#222222", face = "plain", just = "left") {
    grid::grid.text(label, x = x, y = y, just = just,
                    gp = grid::gpar(fontsize = size, col = color, fontface = face,
                                    fontfamily = "sans"))
  }
  seg <- function(x0, x1, y0, y1 = y0, col = "#333333", lwd = 1, lty = 1) {
    grid::grid.lines(x = c(x0, x1), y = c(y0, y1),
                     gp = grid::gpar(col = col, lwd = lwd, lty = lty))
  }
  axis_spec <- function(x, reference) {
    finite <- x[is.finite(x)]
    if (!length(finite)) finite <- c(reference - 1, reference + 1)
    rr <- range(c(finite, reference))
    span <- diff(rr)
    if (span <= 0) span <- max(1, abs(rr[1L]) * 0.2)
    rr <- rr + c(-1, 1) * span * 0.075
    ticks <- pretty(rr, n = 5L)
    ticks <- ticks[ticks >= rr[1L] & ticks <= rr[2L]]
    list(range = rr, ticks = ticks,
         x = function(v) 0.23 + (v - rr[1L]) / diff(rr) * 0.36)
  }
  tick_text <- function(x) {
    format(x, scientific = FALSE, trim = TRUE, big.mark = ",", digits = 5L)
  }
  base_page <- function(title, subtitle, rows, axis, x_label, reference, caption) {
    grid::grid.newpage()
    tx(title, 0.025, 0.955, 18, face = "bold")
    tx(subtitle, 0.025, 0.902, 11)
    tx("Comparison: A - B", 0.025, 0.817, 11, face = "bold")
    yy <- seq(0.745, 0.272, length.out = rows)
    for (i in seq_along(yy)) {
      if (i %% 2L == 0L) grid::grid.rect(x = 0.5, y = yy[i], width = 0.96,
        height = min(0.07, 0.46 / max(1L, rows - 1L)),
        gp = grid::gpar(fill = "#F5F6F7", col = NA))
    }
    for (v in axis$ticks) {
      xx <- axis$x(v)
      seg(xx, xx, 0.235, 0.785, col = "#DFE3E6", lwd = 0.6)
      seg(xx, xx, 0.235, 0.227, col = "#666666", lwd = 0.8)
      tx(tick_text(v), xx, 0.200, 10, just = "center")
    }
    seg(axis$x(reference), axis$x(reference), 0.235, 0.785,
        col = "#555555", lwd = 0.9, lty = 2)
    seg(0.23, 0.59, 0.235, col = "#666666", lwd = 0.8)
    tx(x_label, 0.41, 0.155, 11, just = "center")
    tx(caption, 0.025, 0.068, 9)
    yy
  }
  save <- function(draw, id, benchmark, metric, source, desc_zh, desc_en, ids) {
    png_path <- file.path(figure_dir, paste0(id, ".png"))
    pdf_path <- file.path(figure_dir, paste0(id, ".pdf"))
    if (any(file.exists(c(png_path, pdf_path)))) stop("Refusing existing figure: ", id)
    grDevices::png(png_path, width = 14, height = 6.7, units = "in", res = 170,
                   bg = "white", type = "cairo")
    tryCatch(draw(), finally = grDevices::dev.off())
    grDevices::pdf(pdf_path, width = 14, height = 6.7, family = "sans",
                   useDingbats = FALSE, paper = "special")
    tryCatch(draw(), finally = grDevices::dev.off())
    index[[length(index) + 1L]] <<- data.frame(figure_id = id, benchmark = benchmark,
      metric = metric, png = file.path(figure_subdir, basename(png_path)),
      pdf = file.path(figure_subdir, basename(pdf_path)), input = source,
      unit = if (grepl("^hac_", id)) "HAC SE / paired-t SE (dimensionless)" else unit_names[[metric]],
      level = "paired question repeat-means; conditional on recorded runs",
      comparison_ids = paste(ids, collapse = ";"), description_zh = desc_zh,
      description_en = desc_en, width_in = 14, height_in = 6.7, stringsAsFactors = FALSE)
  }
  for (bench_key in names(benchmark_names)) for (metric_key in names(metric_names)) {
    wanted <- as.character(primary$comparison_id[
      as.character(primary$benchmark) == bench_key & as.character(primary$metric) == metric_key])
    expected_n <- if (metric_key == "latency_s") 6L else 7L
    if (length(wanted) != expected_n) stop("Unexpected forest panel size")
    z <- inference_plot_subset(primary, bench_key, metric_key, wanted)
    plot_id <- paste0("forest_", bench_key, "_", metric_key)
    checks[[length(checks) + 1L]] <- data.frame(figure_id = plot_id,
      expected_rows = expected_n, actual_rows = nrow(z), expected_unique_ids = expected_n,
      actual_unique_ids = length(unique(z$comparison_id)), status = "pass",
      comparison_ids = paste(wanted, collapse = ";"))
    draw_forest <- local({
      zz <- z; mk <- metric_key; bk <- bench_key
      function() {
        valid <- zz$status == "ok" & is.finite(zz$mean_difference) &
          is.finite(zz$ci_low) & is.finite(zz$ci_high)
        if (any(valid & (zz$ci_low > zz$ci_high | zz$mean_difference < zz$ci_low |
                         zz$mean_difference > zz$ci_high))) stop("Invalid interval for plotting")
        axis <- axis_spec(c(zz$ci_low[valid], zz$ci_high[valid]), 0)
        caption <- paste0(
          "Intervals are unadjusted pointwise 95% intervals, not simultaneous intervals. Holm decisions use the original RQ families at alpha = 0.05.\n",
          if (mk == "majority_correct")
            "Newcombe method 10 intervals are approximate; p values use two-sided exact McNemar. Majority correctness is not answer-text voting."
          else "Paired-t inference is conditional on the recorded runs and question model; it does not estimate uncertainty over future reruns.")
        yy <- base_page(paste(metric_names[[mk]], "differences |", benchmark_names[[bk]]),
          "Five-repeat question summaries | A minus B | Unadjusted pointwise 95% intervals",
          nrow(zz), axis, paste0("Difference (", unit_names[[mk]], ")"), 0, caption)
        tx("Estimate [95% interval]", 0.617, 0.817, 11, face = "bold")
        tx("Holm p", 0.818, 0.817, 11, face = "bold")
        tx("Holm decision", 0.905, 0.817, 11, face = "bold")
        decimals <- if (mk %in% c("latency_s", "majority_correct")) 3L else 2L
        fmt <- function(v) formatC(v, format = "f", digits = decimals, big.mark = ",")
        for (i in seq_len(nrow(zz))) {
          a <- as.character(zz$strategy_a[i]); b <- as.character(zz$strategy_b[i])
          col <- strategy_colors[[a]]
          label <- paste0(zz$rq[i], "  ", strategy_names[[a]], " - ", strategy_names[[b]])
          tx(label, 0.025, yy[i], 11, color = col)
          if (valid[i]) {
            lo <- axis$x(zz$ci_low[i]); hi <- axis$x(zz$ci_high[i]); mid <- axis$x(zz$mean_difference[i])
            seg(lo, hi, yy[i], col = col, lwd = 2)
            seg(lo, lo, yy[i] - 0.012, yy[i] + 0.012, col = col, lwd = 1)
            seg(hi, hi, yy[i] - 0.012, yy[i] + 0.012, col = col, lwd = 1)
            grid::grid.points(mid, yy[i], default.units = "npc", pch = 16, size = grid::unit(2.6, "mm"),
                              gp = grid::gpar(col = col))
            tx(paste0(fmt(zz$mean_difference[i]), " [", fmt(zz$ci_low[i]), ", ",
                      fmt(zz$ci_high[i]), "]"), 0.617, yy[i], 10)
          } else tx(paste0("NA (", zz$status[i], ")"), 0.617, yy[i], 10)
          tx(inference_format_p(zz$p_holm[i]), 0.818, yy[i], 10)
          tx(inference_reject_label(zz$reject_h0_holm[i], zz$status[i]), 0.905, yy[i], 10)
        }
        if (any(zz$p_holm == 0, na.rm = TRUE)) tx("* Floating-point underflow; not mathematical zero.", 0.617, 0.155, 8)
      }
    })
    save(draw_forest, plot_id, bench_key, metric_key, "all_primary_tests.csv",
      "按题目配对的 A−B 差及未调整逐比较95%区间；右列独立报告 Holm 判断。不得从区间是否跨零推定校正后判断。",
      "Paired A-minus-B differences and unadjusted pointwise 95% intervals; the separate right column reports Holm decisions, which must not be inferred from interval overlap with zero.", wanted)
  }
  for (bench_key in names(benchmark_names)) for (metric_key in names(metric_names)[1:3]) {
    wanted <- as.character(continuous$comparison_id[
      as.character(continuous$benchmark) == bench_key & as.character(continuous$metric) == metric_key])
    z <- inference_plot_subset(primary, bench_key, metric_key, wanted)
    hz <- hac[as.character(hac$comparison_id) %in% wanted, , drop = FALSE]
    if (nrow(hz) != length(wanted) * 3L || !all(table(hz$comparison_id) == 3L) ||
        any(as.character(hz$benchmark) != bench_key) || any(as.character(hz$metric) != metric_key)) {
      stop("HAC figure membership mismatch")
    }
    plot_id <- paste0("hac_se_ratio_", bench_key, "_", metric_key)
    checks[[length(checks) + 1L]] <- data.frame(figure_id = plot_id,
      expected_rows = length(wanted) * 3L, actual_rows = nrow(hz),
      expected_unique_ids = length(wanted), actual_unique_ids = length(unique(hz$comparison_id)),
      status = "pass", comparison_ids = paste(wanted, collapse = ";"))
    draw_hac <- local({
      zz <- z; hh <- hz; bk <- bench_key; mk <- metric_key
      function() {
        valid <- hh$status == "ok" & is.finite(hh$se_ratio)
        axis <- axis_spec(hh$se_ratio[valid], 1)
        yy <- base_page(paste("HAC standard-error sensitivity |", benchmark_names[[bk]], "|", metric_names[[mk]]),
          "Fixed Bartlett lags 5 / 10 / 20 | prewhite = FALSE | adjust = TRUE | Original query order",
          nrow(zz), axis, "HAC SE / paired-t SE (dimensionless)", 1,
          paste0("Holm correction is separate within each lag and original RQ family; there is no joint error-rate guarantee across the three lags.\n",
                 "HAC assesses short-range order dependence; it does not recover future-run variance or resolve persistent nonstationary drift."))
        tx("Holm decision (alpha = 0.05)", 0.644, 0.855, 11, face = "bold")
        xs <- c(0.656, 0.77, 0.884)
        for (j in 1:3) tx(paste("Lag", c(5, 10, 20)[j]), xs[j], 0.817, 10,
                          color = lag_colors[j], face = "bold")
        for (i in seq_len(nrow(zz))) {
          tx(paste0(zz$rq[i], "  ", strategy_names[[as.character(zz$strategy_a[i])]],
                    " - ", strategy_names[[as.character(zz$strategy_b[i])]]), 0.025, yy[i], 11)
          for (j in 1:3) {
            lag_key <- c(5L, 10L, 20L)[j]
            id_key <- as.character(zz$comparison_id[i])
            h <- hh[as.character(hh$comparison_id) == id_key & hh$lag == lag_key, , drop = FALSE]
            stopifnot(nrow(h) == 1L)
            if (h$status == "ok" && is.finite(h$se_ratio)) {
              grid::grid.points(axis$x(h$se_ratio), yy[i] + c(0.014, 0, -0.014)[j],
                default.units = "npc", pch = c(16, 17, 15)[j], size = grid::unit(2.2, "mm"),
                gp = grid::gpar(col = lag_colors[j]))
            }
            tx(inference_reject_label(h$reject_h0_holm, h$status), xs[j], yy[i], 10)
          }
        }
        for (j in 1:3) {
          x <- 0.645 + (j - 1L) * 0.112
          grid::grid.points(x, 0.155, default.units = "npc", pch = c(16, 17, 15)[j], size = grid::unit(2.2, "mm"),
                            gp = grid::gpar(col = lag_colors[j]))
          tx(paste("lag", c(5, 10, 20)[j]), x + 0.012, 0.155, 10)
        }
      }
    })
    save(draw_hac, plot_id, bench_key, metric_key, "hac_sensitivity.csv; all_primary_tests.csv",
      "固定 lag=5、10、20 的 HAC 与主要配对t标准误之比；右列分别展示每个 lag 的原比较族 Holm 判断。三个 lag 不构成联合错误率保证，也不用于择优。",
      "Ratios of HAC to primary paired-t standard errors at fixed lags 5, 10 and 20. Separate columns show original-family Holm decisions for each lag; there is no across-lag joint guarantee and no selection of a preferred lag.", wanted)
  }
  check_path <- file.path(out, checks_filename)
  if (file.exists(check_path)) stop("Refusing existing figure-input checks")
  data.table::fwrite(data.table::rbindlist(checks), check_path, na = "NA")
  result <- data.table::rbindlist(index)
  stopifnot(nrow(result) == 14L, all(file.exists(file.path(out, result$png))),
            all(file.exists(file.path(out, result$pdf))))
  result
}
