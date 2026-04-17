#!/usr/bin/env Rscript

# ==============================================================================
# CLASSIFY TESTS — auto-klassifikation + manifest-validering + rapport-render
# ==============================================================================
#
# Usage:
#   Rscript dev/classify_tests.R                       # Auto-klassificér, skriv YAML
#   Rscript dev/classify_tests.R --validate            # Validér manifest
#   Rscript dev/classify_tests.R --render-report       # Render markdown-rapport
#   Rscript dev/classify_tests.R --input=<path>        # Override audit-JSON-sti
#   Rscript dev/classify_tests.R --output=<path>       # Override YAML-output-sti
# ==============================================================================

suppressPackageStartupMessages({
  library(yaml)
  library(jsonlite)
})

# Source library med pure functions
# sys.frame(1)$ofile er NULL når kørt via Rscript direkte; brug fallback
lib_path <- tryCatch({
  frame <- sys.frame(1)
  if (!is.null(frame$ofile)) {
    file.path(dirname(frame$ofile), "classify_tests_lib.R")
  } else {
    "dev/classify_tests_lib.R"
  }
}, error = function(e) "dev/classify_tests_lib.R")

if (!file.exists(lib_path)) {
  lib_path <- "dev/classify_tests_lib.R"
}
source(lib_path)

parse_args <- function(args) {
  defaults <- list(
    mode = "classify",
    input = "dev/audit-output/test-audit.json",
    output = "dev/audit-output/test-classification.yaml",
    tests_dir = "tests/testthat",
    report_output = "docs/superpowers/specs/2026-04-17-test-audit-report.md"
  )

  for (arg in args) {
    if (grepl("^--input=", arg)) {
      defaults$input <- sub("^--input=", "", arg)
    } else if (grepl("^--output=", arg)) {
      defaults$output <- sub("^--output=", "", arg)
    } else if (grepl("^--tests-dir=", arg)) {
      defaults$tests_dir <- sub("^--tests-dir=", "", arg)
    } else if (grepl("^--report-output=", arg)) {
      defaults$report_output <- sub("^--report-output=", "", arg)
    } else if (arg == "--validate") {
      defaults$mode <- "validate"
    } else if (arg == "--render-report") {
      defaults$mode <- "render-report"
    } else if (arg %in% c("-h", "--help")) {
      cat("Usage: Rscript dev/classify_tests.R [--validate|--render-report]",
          "[--input=<path>] [--output=<path>]\n")
      quit(save = "no", status = 0)
    } else {
      stop("Ukendt argument: ", arg)
    }
  }

  defaults
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))

  if (args$mode == "classify") {
    stop("classify-mode ikke implementeret endnu (Task 7)")
  } else if (args$mode == "validate") {
    stop("validate-mode ikke implementeret endnu (Task 9)")
  } else if (args$mode == "render-report") {
    stop("render-report-mode ikke implementeret endnu (Task 10)")
  }
}

if (!interactive()) {
  main()
}
