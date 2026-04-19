#!/usr/bin/env Rscript
# ==============================================================================
# run_canonical.R
# ==============================================================================
# §3.3.2 af harden-test-suite-regression-gate openspec change.
#
# CANONICAL test-entrypoint for biSPCharts.
#
# Erstatter legacy `source("global.R")`-baseret runner med pkgload-approach
# (matching `devtools::test()`). Sikrer at alle runners bruger SAMME
# pakke-loading-mekanisme, så test-resultater ikke afviger mellem:
#   - R CMD check (via tests/testthat.R → test_check)
#   - dev/publish_prepare.R
#   - Lokal udvikling (devtools::test())
#   - run_unit_tests.R / run_integration_tests.R / run_performance_tests.R
#
# Usage:
#   Rscript tests/run_canonical.R            # Alle tests (default)
#   Rscript tests/run_canonical.R unit       # Kun tests/testthat/
#   Rscript tests/run_canonical.R integration
#   Rscript tests/run_canonical.R performance
#   Rscript tests/run_canonical.R all        # Eksplicit alle
#
# Exit codes:
#   0 = alle tests bestået
#   1 = én eller flere tests fejlede
# ==============================================================================

run_canonical_tests <- function(scope = c("all", "unit", "integration", "performance"),
                                stop_on_failure = FALSE) {
  scope <- match.arg(scope)

  suppressPackageStartupMessages({
    if (!requireNamespace("pkgload", quietly = TRUE)) {
      stop("pkgload er ikke installeret — kør renv::restore() eller install.packages('pkgload')")
    }
    if (!requireNamespace("testthat", quietly = TRUE)) {
      stop("testthat er ikke installeret")
    }
  })

  project_root <- tryCatch(
    {
      res <- system2("git", c("rev-parse", "--show-toplevel"),
        stdout = TRUE, stderr = FALSE
      )
      trimws(res)
    },
    error = function(e) getwd()
  )

  # Load biSPCharts via pkgload (samme metode som devtools::test())
  if (!"biSPCharts" %in% loadedNamespaces()) {
    pkgload::load_all(project_root, quiet = TRUE, helpers = FALSE)
  }

  dirs_to_run <- switch(scope,
    all = c(
      file.path(project_root, "tests", "testthat"),
      file.path(project_root, "tests", "integration"),
      file.path(project_root, "tests", "performance")
    ),
    unit = file.path(project_root, "tests", "testthat"),
    integration = file.path(project_root, "tests", "integration"),
    performance = file.path(project_root, "tests", "performance")
  )

  existing_dirs <- dirs_to_run[dir.exists(dirs_to_run)]
  if (length(existing_dirs) == 0) {
    message("Ingen test-mapper fundet for scope '", scope, "'")
    return(invisible(NULL))
  }

  all_results <- list()
  for (dir in existing_dirs) {
    cat(sprintf("\n══ %s ══\n\n", basename(dir)))

    res <- testthat::test_dir(
      dir,
      reporter = testthat::SummaryReporter$new(),
      stop_on_failure = FALSE
    )

    all_results[[basename(dir)]] <- as.data.frame(res)
  }

  # Aggreger samlet resultat
  if (length(all_results) == 0) {
    return(invisible(NULL))
  }
  combined <- do.call(rbind, all_results)

  cat("\n══════════════════════════════════════════════════════════════════\n")
  cat(" CANONICAL TEST SUMMARY (scope =", scope, ")\n")
  cat("══════════════════════════════════════════════════════════════════\n")
  cat(sprintf(" Total blocks:    %d\n", nrow(combined)))
  cat(sprintf(" Passed:          %d\n", sum(combined$passed)))
  cat(sprintf(" Failed:          %d\n", sum(combined$failed)))
  cat(sprintf(" Errored:         %d\n", sum(combined$error == TRUE)))
  cat(sprintf(" Skipped:         %d\n", sum(combined$skipped)))

  total_bad <- sum(combined$failed) + sum(combined$error == TRUE)

  if (total_bad > 0 && stop_on_failure) {
    quit(status = 1L)
  }

  invisible(combined)
}

# CLI entry — kør KUN hvis scriptet er top-level Rscript entry-point
# (ikke hvis det sources fra fx publish_prepare.R). sys.nframe() <= 1
# garanterer at vi ikke fejl-parser commandArgs() inden for en funktion-
# scope hvor args tilhører parent-scriptet.
if (!interactive() && sys.nframe() <= 1L) {
  args <- commandArgs(trailingOnly = TRUE)
  scope <- if (length(args) == 0) "all" else args[1]
  valid_scopes <- c("all", "unit", "integration", "performance")
  if (!scope %in% valid_scopes) {
    cat(sprintf(
      "FEJL: ukendt scope '%s'. Gyldige: %s\n",
      scope, paste(valid_scopes, collapse = ", ")
    ))
    quit(status = 1L)
  }

  run_canonical_tests(scope = scope, stop_on_failure = TRUE)
}
