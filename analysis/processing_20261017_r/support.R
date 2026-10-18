# Pure support definitions. No code runs merely by sourcing this file.
csv_new <- function(x, path) {
  if (file.exists(path)) stop(paste("Refusing overwrite:", path))
  data.table::fwrite(x, path, na = "NA", quote = "auto", bom = FALSE)
}
text_new <- function(x, path) {
  con <- file(path, open = "wx", encoding = "UTF-8")
  on.exit(close(con))
  writeLines(enc2utf8(x), con, useBytes = TRUE)
}
write_json_new <- function(x, path) {
  text_new(jsonlite::toJSON(x, pretty = TRUE, auto_unbox = TRUE, null = "null", na = "null", digits = 17), path)
}
snapshot_files <- function(root, exclude = character()) {
  paths <- list.files(root, recursive = TRUE, all.files = TRUE, full.names = TRUE, no.. = TRUE)
  paths <- gsub("\\\\", "/", paths)
  rel <- substring(paths, nchar(root) + 2L)
  keep <- !grepl("(^|/)\\.git(/|$)", rel)
  for (p in exclude) keep <- keep & !startsWith(tolower(paths), paste0(tolower(p), "/")) & tolower(paths) != tolower(p)
  paths <- sort(paths[keep], method = "radix")
  data.frame(path = substring(paths, nchar(root) + 2L), size = as.numeric(file.info(paths)$size),
    sha256 = vapply(paths, digest::digest, character(1), algo = "sha256", file = TRUE, serialize = FALSE), stringsAsFactors = FALSE)
}
verify_snapshot <- function(before, after) {
  common <- intersect(before$path, after$path)
  b <- before[match(common, before$path), , drop = FALSE]
  a <- after[match(common, after$path), , drop = FALSE]
  changed <- common[b$size != a$size | b$sha256 != a$sha256]
  deleted <- setdiff(before$path, after$path)
  added <- setdiff(after$path, before$path)
  list(protected_files = nrow(before), protected_bytes = sum(before$size),
    validation_files = sum(startsWith(before$path, "analysis/validation/")),
    pause_files = sum(startsWith(before$path, "analysis/processing_20261017/")),
    modified = changed, deleted = deleted, unexpected_added = added,
    unchanged = !length(c(changed, deleted, added)),
    scope = "All pre-existing repository files except .git metadata; only the newly created output directory is excluded afterward.")
}
git_state <- function(root) {
  call <- function(args) system2("git", c("-C", shQuote(root), args), stdout = TRUE, stderr = TRUE)
  list(branch = call(c("branch", "--show-current")), commit = call(c("rev-parse", "HEAD")),
    status = call(c("status", "--short")), tracked_diff = call(c("diff", "--stat")))
}
record_runtime <- function(root, out, packages) {
  text_new(capture.output(sessionInfo()), file.path(out, "sessionInfo.txt"))
  csv_new(data.frame(package = packages, version = vapply(packages, function(p) as.character(packageVersion(p)), character(1))),
          file.path(out, "dependencies.csv"))
  text_new(commandArgs(), file.path(out, "command_args.txt"))
  write_json_new(list(R_version = R.version.string, platform = R.version$platform,
    lib_paths = .libPaths(), locale = Sys.getlocale(), timezone = Sys.timezone(),
    command_args = commandArgs(), project_root = root, output_directory = out,
    packages = packages, data_table_threads = data.table::getDTthreads(),
    renv_initialized_by_this_task = FALSE), file.path(out, "runtime.json"))
}
