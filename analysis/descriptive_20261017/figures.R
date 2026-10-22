# Descriptive figures only. Source this file, then call make_figures(input, out).
# All inference is deliberately absent. Approved processing inputs are read-only.

make_figures <- function(input, out) {
  if (!requireNamespace("ggplot2", quietly = TRUE) ||
      !requireNamespace("data.table", quietly = TRUE)) {
    stop("Required packages: ggplot2 and data.table")
  }
  input <- normalizePath(input, winslash = "/", mustWork = TRUE)
  out <- normalizePath(out, winslash = "/", mustWork = TRUE)
  figure_dir <- file.path(out, "figures")
  if (file.exists(figure_dir) || dir.exists(figure_dir)) {
    stop("Refusing to overwrite an existing figures directory: ", figure_dir)
  }
  required <- file.path(input, c("question_summary.csv", "query_metrics.csv"))
  if (!all(file.exists(required))) stop("Missing approved figure input")
  s <- data.table::fread(required[1], na.strings = "NA")
  q <- data.table::fread(required[2], na.strings = "NA")
  strategy_ids <- c("small_only", "medium_only", "large_only", "cascade",
                    "matrix_factorization")
  strategy_names <- c("Small only", "Medium only", "Large only", "Cascade", "MF")
  strategy_axis <- c("Small\nonly", "Medium\nonly", "Large\nonly", "Cascade", "MF")
  strategy_colors <- setNames(c("#0072B2", "#56B4E9", "#D55E00", "#009E73", "#CC79A7"),
                             strategy_names)
  benchmark_names <- c(mmlu_pro = "MMLU-Pro", gsm_hard = "GSM-Hard")
  to_flag <- function(x) tolower(as.character(x)) %in% c("true", "1")
  if (any(!q$strategy %in% strategy_ids) || any(!s$strategy %in% strategy_ids)) {
    stop("Unexpected strategy in figure input")
  }
  q[, strategy_plot := factor(strategy, levels = strategy_ids, labels = strategy_names)]
  s[, strategy_plot := factor(strategy, levels = strategy_ids, labels = strategy_names)]
  q[, correct_numeric := as.numeric(correct_numeric)]
  q[, truncated_flag := to_flag(truncated)]
  q[, extraction_flag := to_flag(extraction_failed)]
  s[, majority_flag := to_flag(majority_correct)]
  s[, latency_s_mean_plot := latency_ms_mean / 1000]
  if (any(!is.finite(s$latency_s_mean_plot)) || any(!is.finite(s$gpu_trapezoid_j_mean)) ||
      any(!is.finite(s$cpu_j_mean)) || any(!is.finite(s$gpu_left_j_mean))) {
    stop("Non-finite question-summary figure value")
  }
  dir.create(figure_dir, recursive = FALSE, showWarnings = FALSE)
  if (!dir.exists(figure_dir)) stop("Could not create figure directory")

  common_theme <- ggplot2::theme_minimal(base_size = 12, base_family = "sans") +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 16),
      plot.subtitle = ggplot2::element_text(size = 11, margin = ggplot2::margin(b = 10)),
      plot.caption = ggplot2::element_text(size = 9, hjust = 0, margin = ggplot2::margin(t = 12)),
      plot.margin = ggplot2::margin(14, 18, 12, 12),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", size = 12),
      legend.position = "bottom", legend.title = ggplot2::element_blank(),
      axis.title = ggplot2::element_text(size = 11)
    )
  strategy_scales <- list(
    ggplot2::scale_color_manual(values = strategy_colors, drop = FALSE),
    ggplot2::scale_fill_manual(values = strategy_colors, drop = FALSE),
    ggplot2::scale_x_discrete(drop = FALSE, labels = setNames(strategy_axis, strategy_names))
  )
  index <- list()
  save_plot <- function(p, id, benchmark, source, unit, level, en, width = 10, height = 7) {
    png <- file.path(figure_dir, paste0(id, ".png"))
    pdf <- file.path(figure_dir, paste0(id, ".pdf"))
    if (file.exists(png) || file.exists(pdf)) stop("Refusing to overwrite figure: ", id)
    ggplot2::ggsave(png, p, device = "png", width = width, height = height,
                   units = "in", dpi = 180, bg = "white", limitsize = TRUE)
    ggplot2::ggsave(pdf, p, device = grDevices::pdf, width = width, height = height,
                   units = "in", bg = "white", useDingbats = FALSE, limitsize = TRUE)
    index[[length(index) + 1L]] <<- data.frame(
      figure_id = id, benchmark = benchmark,
      png = file.path("figures", basename(png)), pdf = file.path("figures", basename(pdf)),
      input = source, unit = unit, level = level,
      description_en = en, width_in = width, height_in = height,
      stringsAsFactors = FALSE
    )
  }
  distribution_plot <- function(d, title, subtitle, y, caption, facet = TRUE) {
    p <- ggplot2::ggplot(d, ggplot2::aes(x = strategy_plot, y = value,
                                       fill = strategy_plot, color = strategy_plot)) +
      ggplot2::geom_violin(trim = TRUE, alpha = 0.16, linewidth = 0.5) +
      ggplot2::geom_point(position = ggplot2::position_jitter(width = 0.105, height = 0, seed = 42),
                          alpha = 0.18, size = 0.8) +
      ggplot2::geom_boxplot(width = 0.15, outlier.shape = NA, alpha = 0.8,
                           linewidth = 0.45) +
      strategy_scales + common_theme + ggplot2::guides(color = "none", fill = "none") +
      ggplot2::labs(title = title, subtitle = subtitle, x = NULL, y = y, caption = caption)
    if (facet) p <- p + ggplot2::facet_wrap(~metric, scales = "free_y", ncol = 2)
    p
  }

  for (benchmark_id in c("mmlu_pro", "gsm_hard")) {
    ss <- s[benchmark == benchmark_id]
    qq <- q[benchmark == benchmark_id]
    bname <- benchmark_names[[benchmark_id]]
    if (nrow(ss) != 1000L || nrow(qq) != 5000L) stop("Unexpected benchmark figure row count")
    energy_note <- if (benchmark_id == "mmlu_pro") {
      "Each point is one question mean; n = 200 per strategy. Small only, question 3030: four complete repeats; all others: five."
    } else {
      "Each point is one question mean across five repeats; n = 200 questions per strategy."
    }
    energy <- data.table::rbindlist(list(
      ss[, .(strategy_plot, query_id, metric = "GPU (two-card sum)", value = gpu_trapezoid_j_mean)],
      ss[, .(strategy_plot, query_id, metric = "CPU", value = cpu_j_mean)]
    ))
    p <- distribution_plot(energy, paste(bname, "| Question energy distributions"),
                           "Gross query-window energy; GPU trapezoid method; separate vertical scales",
                           "Energy (J/query)", paste0(energy_note, "\nViolin, box and points describe the same question-level data; no inferential intervals."))
    save_plot(p, paste0(benchmark_id, "_energy_distribution"), benchmark_id,
              "question_summary.csv", "J/query", "question_mean",
              "GPU and CPU gross-energy distributions of question means; panels use separate vertical scales.",
              width = 11, height = 7)

    latency <- ss[, .(strategy_plot, value = latency_s_mean_plot)]
    p <- distribution_plot(latency, paste(bname, "| Question latency distribution"),
                           "Original monotonic end-to-end latency; milliseconds divided by 1000",
                           "Latency (s/query)",
                           "Each point is one question mean across five repeats; n = 200 per strategy.\nThe full query includes embedding, routing and all generation calls. No inferential intervals.",
                           facet = FALSE)
    save_plot(p, paste0(benchmark_id, "_latency_distribution"), benchmark_id,
              "question_summary.csv", "s/query", "question_mean",
              "Distribution of five-repeat question latency means, converted from milliseconds to seconds; full query window.")

    runs <- data.table::rbindlist(lapply(c("gpu_trapezoid_j", "cpu_j", "latency_ms"), function(field) {
      z <- qq[, .(value = mean(get(field), na.rm = TRUE), n_valid = sum(is.finite(get(field)))),
              by = .(strategy_plot, run_id, repetition)]
      z[, metric := switch(field, gpu_trapezoid_j = "GPU gross (J/query)",
                           cpu_j = "CPU gross (J/query)", latency_ms = "Latency (s/query)")]
      if (field == "latency_ms") z[, value := value / 1000]
      z
    }))
    runs[, metric := factor(metric, levels = c("GPU gross (J/query)", "CPU gross (J/query)", "Latency (s/query)"))]
    runs[, x_position := as.numeric(strategy_plot) + (repetition - 3) * 0.10]
    runs[, denominator := ifelse(n_valid == 199, "199 complete-energy questions", "200 questions")]
    p <- ggplot2::ggplot(runs, ggplot2::aes(x = x_position, y = value, color = strategy_plot,
                                         shape = denominator)) +
      ggplot2::geom_point(size = 3.1, alpha = 0.9) +
      ggplot2::facet_wrap(~metric, scales = "free_y", ncol = 3) +
      ggplot2::scale_color_manual(values = strategy_colors, drop = FALSE) +
      ggplot2::scale_shape_manual(values = c("200 questions" = 16, "199 complete-energy questions" = 17)) +
      ggplot2::scale_x_continuous(breaks = seq_along(strategy_names), labels = strategy_axis) +
      common_theme + ggplot2::guides(color = "none") +
      ggplot2::labs(title = paste(bname, "| Variation across five runs"),
                    subtitle = "Means of complete query metrics within each run; each panel has its own unit and vertical scale",
                    x = NULL, y = "Run mean", caption = paste0(
                      "Each dot is one run. Within each strategy, repetition 1 to 5 is offset from left to right; offsets are not time.\n",
                      if (benchmark_id == "mmlu_pro") "Triangle: Small only repetition 4 has 199 complete-energy queries; its latency mean still uses 200." else
                        "All displayed run means use 200 queries. Identical repetition labels do not establish matched run blocks."))
    save_plot(p, paste0(benchmark_id, "_run_means"), benchmark_id, "query_metrics.csv",
              "J/query; s/query", "run_mean",
              "Five run means per strategy; horizontal offsets identify repetitions 1 to 5; a triangle marks energy denominator 199.",
              width = 12, height = 6.8)

    acc_runs <- qq[, .(value = 100 * mean(correct_numeric)), by = .(strategy_plot, repetition)]
    acc_runs[, `:=`(type = "Individual run (200 questions)", x_position = as.numeric(strategy_plot) + (repetition - 3) * 0.075)]
    acc_majority <- ss[, .(value = 100 * mean(majority_flag)), by = strategy_plot]
    acc_majority[, `:=`(type = "Majority correctness (200 questions)", x_position = as.numeric(strategy_plot) - 0.29)]
    acc_mean <- ss[, .(value = 100 * mean(mean_correct)), by = strategy_plot]
    acc_mean[, `:=`(type = "Mean of five run accuracies", x_position = as.numeric(strategy_plot) + 0.29)]
    acc <- data.table::rbindlist(list(acc_runs[, .(strategy_plot, value, type, x_position)], acc_majority, acc_mean), use.names = TRUE)
    p <- ggplot2::ggplot(acc, ggplot2::aes(x = x_position, y = value, color = strategy_plot, shape = type)) +
      ggplot2::geom_point(size = 3.2, stroke = 1.0) +
      ggplot2::scale_color_manual(values = strategy_colors, drop = FALSE) +
      ggplot2::scale_shape_manual(values = c("Majority correctness (200 questions)" = 18,
                                           "Individual run (200 questions)" = 1,
                                           "Mean of five run accuracies" = 4)) +
      ggplot2::scale_x_continuous(breaks = seq_along(strategy_names), labels = strategy_axis) +
      ggplot2::scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20)) +
      common_theme + ggplot2::guides(color = "none", shape = ggplot2::guide_legend(nrow = 2, byrow = TRUE)) +
      ggplot2::labs(title = paste(bname, "| Distinct accuracy summaries"),
                    subtitle = "Majority correctness, individual run accuracy and average run accuracy are separate quantities",
                    x = NULL, y = "Accuracy (%)", caption =
                      "Majority correctness means at least 3 correct outcomes among 5 repeats, not an answer-text vote.\nOpen circles show repetitions 1 to 5 from left to right, including equal accuracies; no inferential intervals are shown.")
    save_plot(p, paste0(benchmark_id, "_accuracy"), benchmark_id,
              "question_summary.csv; query_metrics.csv", "%", "question_majority_and_run",
              "Majority correctness, five individual run accuracies and mean run accuracy are displayed separately, without inferential intervals.",
              width = 10, height = 7.2)

    tradeoff <- ss[, .(gpu = mean(gpu_trapezoid_j_mean), cpu = mean(cpu_j_mean),
                      accuracy = 100 * mean(majority_flag)), by = strategy_plot]
    tradeoff <- data.table::melt(tradeoff, id.vars = c("strategy_plot", "accuracy"),
                                measure.vars = c("gpu", "cpu"), variable.name = "device", value.name = "energy")
    tradeoff[, device := factor(device, levels = c("gpu", "cpu"), labels = c("GPU (two-card sum)", "CPU"))]
    p <- ggplot2::ggplot(tradeoff, ggplot2::aes(x = energy, y = accuracy,
                                             color = strategy_plot, shape = strategy_plot)) +
      ggplot2::geom_point(size = 4.1, stroke = 1) +
      ggplot2::facet_wrap(~device, scales = "free_x") +
      ggplot2::scale_color_manual(values = strategy_colors, drop = FALSE) +
      ggplot2::scale_shape_manual(values = setNames(c(16, 17, 15, 18, 8), strategy_names), drop = FALSE) +
      ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.12, 0.12))) +
      ggplot2::scale_y_continuous(expand = ggplot2::expansion(add = 1)) + common_theme +
      ggplot2::labs(title = paste(bname, "| Gross energy and majority accuracy"),
                    subtitle = "One descriptive point per strategy; no confidence intervals or dominance claims",
                    x = "Mean question energy (J/query)", y = "Majority-correct accuracy (%)",
                    caption = paste0("Energy is the equally weighted mean of 200 question means; accuracy is majority-correct count / 200.\n",
                                     if (benchmark_id == "mmlu_pro") "Small only question 3030 uses four energy repeats; all other energy cells use five." else
                                       "Every energy question mean uses five repeats. Horizontal axes differ between devices."))
    save_plot(p, paste0(benchmark_id, "_energy_accuracy"), benchmark_id, "question_summary.csv",
              "J/query; %", "strategy_summary_of_questions",
              "Descriptive tradeoff between equal-weight mean question energy and majority accuracy over 200 questions; no significance or statistical dominance interpretation.",
              width = 11, height = 6.5)

    models <- qq[, .N, by = .(strategy_plot, final_model)]
    models[, proportion_pct := 100 * N / sum(N), by = strategy_plot]
    models[, final_model := factor(final_model, levels = c("qwen3.5:4b", "qwen3.5:9b", "qwen3.5:27b"),
                                    labels = c("Qwen3.5 4B", "Qwen3.5 9B", "Qwen3.5 27B"))]
    models[, label := ifelse(proportion_pct >= 4, paste0(format(round(proportion_pct, 1), trim = TRUE), "%"), "")]
    p <- ggplot2::ggplot(models, ggplot2::aes(x = strategy_plot, y = proportion_pct, fill = final_model)) +
      ggplot2::geom_col(width = 0.7, color = "white", linewidth = 0.4) +
      ggplot2::geom_text(ggplot2::aes(label = label), position = ggplot2::position_stack(vjust = 0.5),
                         size = 3.4, color = "black") +
      ggplot2::scale_fill_manual(values = c("Qwen3.5 4B" = "#A8DADC", "Qwen3.5 9B" = "#F4D35E", "Qwen3.5 27B" = "#EE9185"), drop = FALSE) +
      ggplot2::scale_x_discrete(drop = FALSE, labels = setNames(strategy_axis, strategy_names)) +
      ggplot2::scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20), expand = ggplot2::expansion(mult = c(0, 0.02))) +
      common_theme + ggplot2::labs(title = paste(bname, "| Final model selection"),
                                  subtitle = "Final-answer model only; proportions include all five repetitions",
                                  x = NULL, y = "Share of query executions (%)", caption =
                                    "Denominator: 1000 query executions per strategy (200 repeated questions, not 1000 independent items).\nRejected cascade calls and MF embeddings remain in energy, latency and call totals; labels below 4% are omitted.")
    save_plot(p, paste0(benchmark_id, "_final_models"), benchmark_id, "query_metrics.csv",
              "% of 1000 query executions per strategy", "query_execution_final_model",
              "Final-answer model shares among 1000 query executions per strategy, not 1000 independent questions.")

    quality <- qq[, .(truncation = 100 * mean(truncated_flag), extraction_failure = 100 * mean(extraction_flag)), by = strategy_plot]
    quality <- data.table::melt(quality, id.vars = "strategy_plot", variable.name = "metric", value.name = "value")
    quality[, metric := factor(metric, levels = c("truncation", "extraction_failure"),
                               labels = c("Final-output truncation", "Answer extraction failure"))]
    p <- ggplot2::ggplot(quality, ggplot2::aes(x = strategy_plot, y = value, fill = strategy_plot)) +
      ggplot2::geom_col(width = 0.66, alpha = 0.85) +
      ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f%%", value)), vjust = -0.45, size = 3.5) +
      ggplot2::facet_wrap(~metric, ncol = 2) +
      ggplot2::scale_fill_manual(values = strategy_colors, drop = FALSE) +
      ggplot2::scale_x_discrete(drop = FALSE, labels = setNames(strategy_axis, strategy_names)) +
      ggplot2::scale_y_continuous(limits = c(0, 105), breaks = seq(0, 100, 20), expand = ggplot2::expansion(mult = c(0, 0))) +
      common_theme + ggplot2::guides(fill = "none") +
      ggplot2::labs(title = paste(bname, "| Recorded output-quality flags"),
                    subtitle = "Rates use unchanged final-query flags; no records are excluded",
                    x = NULL, y = "Share of query executions (%)", caption =
                      "Each rate uses 1000 query executions per strategy. Truncation and extraction failure can overlap.\nA truncated answer can still score correct under the preserved scoring implementation.")
    save_plot(p, paste0(benchmark_id, "_quality_flags"), benchmark_id, "query_metrics.csv",
              "% of 1000 query executions per strategy", "query_execution_final_output",
              "Final-output truncation and extraction-failure rates among 1000 query executions per strategy; flags may overlap.",
              width = 11, height = 6.5)

    sensitivity <- data.table::rbindlist(list(
      ss[, .(strategy_plot, metric = "Absolute difference (J/query)", value = abs(gpu_left_j_mean - gpu_trapezoid_j_mean))],
      ss[, .(strategy_plot, metric = "Relative difference (%)", value = 100 * (gpu_left_j_mean - gpu_trapezoid_j_mean) / gpu_trapezoid_j_mean)]
    ))
    sensitivity[, metric := factor(metric, levels = c("Absolute difference (J/query)", "Relative difference (%)"))]
    p <- distribution_plot(sensitivity, paste(bname, "| GPU integration-method sensitivity"),
                           "Differences between left hold and trapezoid, evaluated on the same question repeat means",
                           "Difference (unit in panel title)",
                           "Left panel: |left hold - trapezoid| in J/query. Right panel: 100 x (left hold - trapezoid) / trapezoid.\n200 question means per strategy; separate vertical scales. This describes method sensitivity, not sensor precision or an effect size.")
    save_plot(p, paste0(benchmark_id, "_method_sensitivity"), benchmark_id, "question_summary.csv",
              "absolute J/query; signed %", "question_mean_method_difference",
              "Question-mean integration differences: absolute |left hold - trapezoid| and signed relative percent; not sensor accuracy or a formal effect size.",
              width = 11.5, height = 7)
  }
  data.table::rbindlist(index, use.names = TRUE, fill = FALSE)
}
