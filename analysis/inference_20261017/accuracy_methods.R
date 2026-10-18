# New analysis only. Defines functions; importing does not read data or write files.
# Newcombe (1998), Statistics in Medicine 17:2635-2650, method 10, p.2639.
# a=both correct, b=A only, c=B only, d=both incorrect.

accuracy_count_error <- function(a, b, c, d, conf.level = 0.95) {
  cells <- list(a, b, c, d)
  if (any(!vapply(cells, function(v) is.numeric(v) && length(v) == 1L &&
                 is.finite(v) && v >= 0 && v == floor(v), logical(1))))
    return("Counts must be finite, nonnegative scalar integers; no missing pair is dropped.")
  if (!is.finite(sum(unlist(cells))) || sum(unlist(cells)) <= 0)
    return("A positive finite total number of pairs is required.")
  if (!is.numeric(conf.level) || length(conf.level) != 1L ||
      !is.finite(conf.level) || conf.level <= 0 || conf.level >= 1)
    return("Confidence level must be a finite scalar strictly between zero and one.")
  ""
}

wilson_marginal <- function(successes, n, conf.level = 0.95) {
  # Ordinary Wilson score bounds, WITHOUT marginal continuity correction.
  p <- successes / n
  z <- stats::qnorm(1 - (1 - conf.level) / 2)
  denominator <- 1 + z^2 / n
  center <- (p + z^2 / (2 * n)) / denominator
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / denominator
  lower <- center - half
  upper <- center + half
  if (successes == 0) lower <- 0
  if (successes == n) upper <- 1
  c(lower = lower, upper = upper)
}

newcombe10_ci <- function(a, b, c, d, conf.level = 0.95) {
  fail <- function(reason) list(estimate = NA_real_, lower = NA_real_,
    upper = NA_real_, phi_corrected = NA_real_, phi_denominator = NA_real_,
    roundoff_adjusted = FALSE, status = "failed", reason = reason)
  error <- accuracy_count_error(a, b, c, d, conf.level)
  if (nzchar(error)) return(fail(error))
  n <- a + b + c + d
  p_a <- (a + b) / n
  p_b <- (a + c) / n
  estimate <- (b - c) / n
  marginal_a <- wilson_marginal(a + b, n, conf.level)
  marginal_b <- wilson_marginal(a + c, n, conf.level)
  phi_denominator <- sqrt((a + b) * (c + d) * (a + c) * (b + d))
  phi_numerator <- a * d - b * c
  if (!is.finite(phi_denominator) || !is.finite(phi_numerator))
    return(fail("Cell-product overflow: no correlation or confidence interval inferred."))
  if (phi_denominator == 0) {
    phi <- 0
  } else {
    # Correction applies ONLY to a positive uncorrected association numerator.
    if (phi_numerator > 0) phi_numerator <- max(phi_numerator - n / 2, 0)
    phi <- phi_numerator / phi_denominator
  }
  x_lower <- p_a - marginal_a[["lower"]]
  y_upper <- marginal_b[["upper"]] - p_b
  x_upper <- marginal_a[["upper"]] - p_a
  y_lower <- p_b - marginal_b[["lower"]]
  radicands <- c(x_lower^2 + y_upper^2 - 2 * phi * x_lower * y_upper,
                x_upper^2 + y_lower^2 - 2 * phi * x_upper * y_lower)
  roundoff_tol <- 1e-14
  if (any(!is.finite(radicands)) || any(radicands < -roundoff_tol) || abs(phi) > 1 + roundoff_tol)
    return(fail("Invalid Newcombe square-root or correlation: no replacement method used."))
  roundoff_adjusted <- any(radicands < 0)
  radicands <- pmax(radicands, 0) # numerical cancellation only, tolerance stated above
  limits <- c(estimate - sqrt(radicands[1]), estimate + sqrt(radicands[2]))
  if (limits[1] < -1 - roundoff_tol || limits[2] > 1 + roundoff_tol ||
      limits[1] > estimate + roundoff_tol || limits[2] < estimate - roundoff_tol)
    return(fail("Newcombe limits failed parameter-space or containment validation."))
  if (limits[1] < -1 || limits[2] > 1) {
    roundoff_adjusted <- TRUE
    limits <- pmax(-1, pmin(1, limits))
  }
  list(estimate = estimate, lower = limits[1], upper = limits[2],
       phi_corrected = phi, phi_denominator = phi_denominator,
       roundoff_adjusted = roundoff_adjusted, status = "ok",
       reason = if (phi_denominator == 0) "Zero marginal denominator: phi=0 as specified in method 8, retained by method 10." else "")
}

accuracy_inference_counts <- function(a, b, c, d, conf.level = 0.95) {
  error <- accuracy_count_error(a, b, c, d, conf.level)
  scalar_cell <- function(v) if (is.numeric(v) && length(v) == 1L) as.numeric(v) else NA_real_
  result <- data.frame(n_pairs = NA_real_, a = scalar_cell(a), b = scalar_cell(b),
    c = scalar_cell(c), d = scalar_cell(d), discordant = NA_real_,
    mean_a = NA_real_, mean_b = NA_real_, accuracy_a_pct = NA_real_, accuracy_b_pct = NA_real_,
    estimate = NA_real_, mean_difference = NA_real_, ci_low = NA_real_, ci_high = NA_real_,
    p_raw = NA_real_, unit = "percentage_points", method = "exact_binomial_mcnemar",
    ci_method = "newcombe_1998_method10_paired", confidence_level = scalar_cell(conf.level),
    ci_multiplicity = "unadjusted_pointwise", phi_corrected = NA_real_,
    ci_roundoff_adjusted = FALSE, status = "failed", reason = error,
    stringsAsFactors = FALSE)
  if (nzchar(error)) return(result)
  n <- a + b + c + d
  ci <- newcombe10_ci(a, b, c, d, conf.level)
  result$n_pairs <- n
  result$discordant <- b + c
  result$mean_a <- (a + b) / n
  result$mean_b <- (a + c) / n
  result$accuracy_a_pct <- 100 * result$mean_a
  result$accuracy_b_pct <- 100 * result$mean_b
  result$estimate <- result$mean_difference <- 100 * (b - c) / n
  if (ci$status != "ok") {
    result$reason <- ci$reason
    return(result)
  }
  exact_p <- if (b + c == 0) 1 else tryCatch(
    stats::binom.test(b, b + c, p = 0.5, alternative = "two.sided")$p.value,
    error = function(e) NA_real_)
  if (!is.finite(exact_p) || exact_p < 0 || exact_p > 1) {
    result$reason <- "Exact binomial McNemar failed; no approximate substitute used."
    return(result)
  }
  result$p_raw <- exact_p
  result$ci_low <- 100 * ci$lower
  result$ci_high <- 100 * ci$upper
  result$phi_corrected <- ci$phi_corrected
  result$ci_roundoff_adjusted <- ci$roundoff_adjusted
  result$status <- "ok"
  result$reason <- paste(c(if (b + c == 0)
    "No observed discordant pair: p=1 by the approved convention; not evidence of equivalence.",
    if (nzchar(ci$reason)) ci$reason), collapse = " ")
  result
}
