#!/usr/bin/env Rscript
# ==============================================================================
# run_e2e.R
# ==============================================================================
# §4.1.1 af harden-test-suite-regression-gate openspec change.
#
# E2E test-runner for biSPCharts headless shinytest2-suite.
#
# Separat entrypoint fra testthat::test_dir() for at:
#   - Undgå auto-discovery i R CMD check (tests/testthat/ scope)
#   - Tillade Chrome-availability-gate
#   - Håndtere flaky shinytest2-tests med retry-mekanisme
#
# Usage:
#   Rscript tests/e2e/run_e2e.R
#   E2E_RETRY=2 Rscript tests/e2e/run_e2e.R       # 2 retries på fejl
#   E2E_UPDATE_SNAPS=true Rscript tests/e2e/run_e2e.R   # Opdater snapshots
#
# Exit codes:
#   0 = alle E2E-tests bestået (eller Chrome ikke tilgængelig — skip)
#   1 = E2E-fejl efter retries
# ==============================================================================

run_e2e <- function(retry_count = NULL) {
  retry_count <- retry_count %||% as.integer(Sys.getenv("E2E_RETRY", "2"))
  if (is.na(retry_count) || retry_count < 0) retry_count <- 2L

  suppressPackageStartupMessages({
    if (!requireNamespace("shinytest2", quietly = TRUE)) {
      cat("⚠ shinytest2 ikke installeret — E2E-tests springes over\n")
      return(invisible(NULL))
    }
    if (!requireNamespace("chromote", quietly = TRUE)) {
      cat("⚠ chromote ikke installeret — E2E-tests springes over\n")
      return(invisible(NULL))
    }
  })

  # Chrome-availability check
  chrome_ok <- tryCatch(
    shinytest2::detect_chrome() != "",
    error = function(e) FALSE
  )

  if (!chrome_ok) {
    cat("⚠ Chrome/Chromium ikke fundet — E2E-tests springes over\n")
    cat("  For at aktivere: installér Chrome eller sæt CHROMOTE_CHROME-env\n")
    return(invisible(NULL))
  }

  project_root <- tryCatch(
    trimws(system2("git", c("rev-parse", "--show-toplevel"),
      stdout = TRUE, stderr = FALSE
    )),
    error = function(e) getwd()
  )

  e2e_dir <- file.path(project_root, "tests", "e2e")

  cat("════════════════════════════════════════════════════════════════\n")
  cat(" biSPCharts E2E suite (retry=", retry_count, ")\n", sep = "")
  cat("════════════════════════════════════════════════════════════════\n")

  # Load package via pkgload (matching canonical runner §3.3)
  if (!"biSPCharts" %in% loadedNamespaces()) {
    if (requireNamespace("pkgload", quietly = TRUE)) {
      pkgload::load_all(project_root, quiet = TRUE, helpers = FALSE)
    }
  }

  update_snaps <- toupper(Sys.getenv("E2E_UPDATE_SNAPS", "false")) == "TRUE"
  if (update_snaps) {
    Sys.setenv(TESTTHAT_UPDATE_SNAPS = "true")
  }

  attempts <- 0L
  repeat {
    attempts <- attempts + 1L
    cat(sprintf("\n── Attempt %d/%d ──\n", attempts, retry_count + 1L))

    res <- tryCatch(
      testthat::test_dir(
        e2e_dir,
        reporter = testthat::SummaryReporter$new(),
        stop_on_failure = FALSE
      ),
      error = function(e) {
        cat(sprintf("E2E attempt %d fejlede: %s\n", attempts, e$message))
        NULL
      }
    )

    if (!is.null(res)) {
      df <- as.data.frame(res)
      fails <- sum(df$failed)
      errs <- sum(df$error == TRUE)

      if (fails == 0 && errs == 0) {
        cat(sprintf(
          "\n✓ E2E OK (%d pass, %d skip)\n",
          sum(df$passed), sum(df$skipped)
        ))
        return(invisible(df))
      }

      cat(sprintf(
        "\n✗ E2E attempt %d: %d fail, %d err\n",
        attempts, fails, errs
      ))
    }

    if (attempts > retry_count) {
      cat(sprintf(
        "\n✗ E2E fejlede efter %d forsøg — push blokeret\n",
        attempts
      ))
      if (!interactive()) quit(status = 1L)
      return(invisible(NULL))
    }
    cat(sprintf("  Retry %d/%d i 5 sekunder ...\n", attempts, retry_count))
    Sys.sleep(5)
  }
}

`%||%` <- function(x, y) if (is.null(x)) y else x

if (!interactive()) {
  run_e2e()
}
