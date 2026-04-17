#!/usr/bin/env Rscript

# ==============================================================================
# AUDIT TESTS — hovedscript (#203)
# ==============================================================================
#
# Usage:
#   Rscript dev/audit_tests.R
#   Rscript dev/audit_tests.R --filter='test-auto'
#   Rscript dev/audit_tests.R --timeout=120
#   Rscript dev/audit_tests.R --output-dir=dev/audit-output
# ==============================================================================

suppressPackageStartupMessages({
  library(processx)
  library(jsonlite)
  library(pkgload)
})

project_root <- getwd()
audit_dir <- file.path(project_root, "dev", "audit")
source(file.path(audit_dir, "static_analysis.R"))
source(file.path(audit_dir, "dynamic_runner.R"))
source(file.path(audit_dir, "classifier.R"))
source(file.path(audit_dir, "reporter.R"))

parse_args <- function(args) {
  defaults <- list(
    filter = NULL,
    output_dir = "dev/audit-output",
    timeout = 60L,
    report_md = "docs/superpowers/specs/2026-04-17-test-audit-report.md"
  )

  for (arg in args) {
    if (grepl("^--filter=", arg)) {
      defaults$filter <- sub("^--filter=", "", arg)
    } else if (grepl("^--output-dir=", arg)) {
      defaults$output_dir <- sub("^--output-dir=", "", arg)
    } else if (grepl("^--timeout=", arg)) {
      defaults$timeout <- as.integer(sub("^--timeout=", "", arg))
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript dev/audit_tests.R [--filter=<regex>] [--output-dir=<path>] [--timeout=<sec>]\n")
      quit(save = "no", status = 0)
    }
  }

  defaults
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))

  cat("Loading biSPCharts package...\n")
  pkgload::load_all(quiet = TRUE)

  cat("Scanning testfiler...\n")
  all_files <- scan_test_files("tests/testthat")
  if (!is.null(args$filter)) {
    all_files <- all_files[grepl(args$filter, basename(all_files))]
  }
  cat(sprintf("  Fundet %d filer.\n", length(all_files)))

  if (length(all_files) == 0) {
    stop("Ingen testfiler matchede filteret.")
  }

  cat("Henter R-exports...\n")
  r_exports <- list_r_exports()
  cat(sprintf("  Fundet %d funktioner i R/.\n", length(r_exports)))

  cat(sprintf("\nKoerer audit (timeout %ds pr. fil)...\n", args$timeout))
  dir.create(args$output_dir, showWarnings = FALSE, recursive = TRUE)
  start_total <- Sys.time()

  results <- lapply(seq_along(all_files), function(i) {
    file <- all_files[i]
    cat(sprintf("  [%d/%d] %s ... ", i, length(all_files), basename(file)))

    static <- list(
      file = basename(file),
      loc = count_loc(file),
      last_modified = file.info(file)$mtime,
      n_test_blocks = count_test_blocks(file),
      has_deprecation_marker = detect_deprecation_marker(file),
      function_calls = extract_function_calls(file)
    )
    static$missing_functions_static <- setdiff(static$function_calls, r_exports)

    dyn_raw <- run_test_file_isolated(file, timeout = args$timeout, pkg_root = project_root)
    parsed <- parse_testthat_output(dyn_raw$stdout)
    missing_rt <- extract_missing_functions(dyn_raw$stderr)
    drift <- detect_api_drift(dyn_raw$stderr)

    dynamic <- list(
      exit_code = dyn_raw$exit_code,
      elapsed_s = dyn_raw$elapsed_s,
      n_pass = parsed$n_pass,
      n_fail = parsed$n_fail,
      n_skip = parsed$n_skip,
      missing_functions = missing_rt,
      api_drift_detected = drift,
      timed_out = isTRUE(dyn_raw$timed_out),
      stderr_snippet = substr(paste(dyn_raw$stderr, collapse = "\n"), 1, 500)
    )

    category <- classify_file(static, dynamic)

    cat(sprintf("%s (%.1fs)\n", category, dynamic$elapsed_s))

    c(static, dynamic, list(category = category))
  })

  total_elapsed <- as.numeric(difftime(Sys.time(), start_total, units = "secs"))

  summary_info <- compute_summary(results)
  final <- list(
    run_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    biSPCharts_version = as.character(utils::packageVersion("biSPCharts")),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    total_files = length(results),
    total_elapsed_s = total_elapsed,
    summary = summary_info$summary,
    top_missing_functions = summary_info$top_missing_functions,
    files = results
  )

  json_path <- file.path(args$output_dir, "test-audit.json")
  md_path <- args$report_md
  dir.create(dirname(md_path), showWarnings = FALSE, recursive = TRUE)

  write_json_report(final, json_path)
  write_markdown_report(final, md_path)
  print_console_summary(final)

  cat(sprintf("\nJSON: %s\n", json_path))
  cat(sprintf("MD:   %s\n", md_path))
}

if (!interactive() && sys.nframe() == 0L) {
  main()
}
