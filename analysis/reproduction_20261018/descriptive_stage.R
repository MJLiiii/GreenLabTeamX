# Unified reproduction adapter. Reuses reviewed descriptive calculations unchanged.
# Importing this file defines one function; it performs no reads or writes.

run_descriptive_stage <- function(root, processing_dir, out) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  processing_dir <- normalizePath(processing_dir, winslash = "/", mustWork = TRUE)
  if (!dir.exists(processing_dir)) stop("Processing input must be an existing directory")
  if (file.exists(out) || dir.exists(out)) stop("Descriptive output exists; refusing overwrite: ", out)
  output_parent <- normalizePath(dirname(out), winslash = "/", mustWork = TRUE)
  output_name <- basename(out)
  if (!nzchar(output_name) || output_name %in% c(".", "..")) stop("Invalid descriptive output name")
  out <- file.path(output_parent, output_name)
  if (!startsWith(out, paste0(root, "/analysis/"))) stop("Descriptive output must be under project analysis/")
  if (file.exists(out) || dir.exists(out)) stop("Descriptive output already exists after resolution")
  if (!startsWith(processing_dir, paste0(root, "/analysis/"))) stop("Processing input must be under project analysis/")
  historical_input <- file.path(root, "analysis/outputs_20261017_02")
  if (identical(processing_dir, historical_input)) stop("This adapter requires the newly generated processing directory")
  for (pkg in c("data.table", "ggplot2", "digest")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop("Missing descriptive dependency: ", pkg)
  }

  input_names <- c("query_metrics.csv", "question_summary.csv", "run_reconciliation.csv",
                   "idle_summary.csv", "run_resources.csv")
  input_paths <- file.path(processing_dir, input_names)
  if (!all(file.exists(input_paths))) stop("New processing input files are incomplete")
  module_paths <- file.path(root, "analysis/descriptive_20261017", c("tables.R", "figures.R"))
  if (!all(file.exists(module_paths))) stop("Reviewed descriptive modules are missing")
  fingerprint <- function(paths) data.table::data.table(
    path = normalizePath(paths, winslash = "/", mustWork = TRUE),
    sha256 = vapply(paths, function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE), character(1)))
  input_hashes <- fingerprint(input_paths)
  module_hashes <- fingerprint(module_paths)
  read_input <- function(name) data.table::fread(file.path(processing_dir, name),
                                               na.strings = "NA", integer64 = "double")
  q <- read_input("query_metrics.csv")
  s <- read_input("question_summary.csv")
  r <- read_input("run_reconciliation.csv")
  idle <- read_input("idle_summary.csv")
  resources <- read_input("run_resources.csv")
  if (!identical(c(nrow(q), nrow(s), nrow(r), nrow(idle), nrow(resources)),
                 c(10000L, 2000L, 55L, 5L, 55L))) stop("Unexpected new-processing input row counts")

  # Keep definitions local. Do not invoke historical stage entry, gates, tests,
  # reports, inventory scans, or historical pending-approval metadata writers.
  env <- new.env(parent = globalenv())
  for (path in module_paths) source(path, local = env, encoding = "UTF-8")
  if (!is.function(env$make_tables) || !is.function(env$make_figures)) stop("Reviewed module interface unavailable")
  if (!dir.create(out, recursive = FALSE, showWarnings = FALSE)) stop("Cannot create fresh descriptive output")
  tables <- env$make_tables(q, s, r, idle, resources, out)
  figure_index <- env$make_figures(processing_dir, out)
  if (length(tables) != 14L || nrow(figure_index) != 16L) stop("Unexpected descriptive artifact count")
  index_path <- file.path(out, "figures_index.csv")
  if (file.exists(index_path)) stop("Refusing existing descriptive figure index")
  data.table::fwrite(figure_index, index_path, na = "NA")
  list(tables = tables, figure_index = figure_index,
       processing_dir = processing_dir, output_dir = out,
       input_hashes = input_hashes, module_hashes = module_hashes,
       input_rows = stats::setNames(c(nrow(q), nrow(s), nrow(r), nrow(idle), nrow(resources)), input_names),
       table_rows = vapply(tables, nrow, integer(1)),
       reused_functions = c("make_tables", "make_figures"),
       historical_tests_reexecuted = FALSE, historical_preflight_invoked = FALSE)
}
