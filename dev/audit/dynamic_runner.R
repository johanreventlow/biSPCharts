# ==============================================================================
# AUDIT: Dynamic runner (#203)
# ==============================================================================

#' Parse testthat ProgressReporter output til taelletal
parse_testthat_output <- function(stdout) {
  pattern <- "\\[\\s*FAIL\\s+(\\d+)\\s*\\|\\s*WARN\\s+\\d+\\s*\\|\\s*SKIP\\s+(\\d+)\\s*\\|\\s*PASS\\s+(\\d+)\\s*\\]"
  matches <- regmatches(stdout, regexec(pattern, stdout))
  hits <- Filter(function(m) length(m) > 1, matches)

  if (length(hits) == 0) {
    return(list(n_pass = 0L, n_fail = 0L, n_skip = 0L))
  }

  last <- hits[[length(hits)]]
  list(
    n_fail = as.integer(last[2]),
    n_skip = as.integer(last[3]),
    n_pass = as.integer(last[4])
  )
}

#' Ekstraher manglende funktionsnavne fra stderr
extract_missing_functions <- function(stderr) {
  if (length(stderr) == 0) return(character(0))
  text <- paste(stderr, collapse = "\n")
  pattern <- "could not find function\\s+[\"']([^\"']+)[\"']"
  matches <- regmatches(text, gregexpr(pattern, text))[[1]]
  if (length(matches) == 0) return(character(0))

  fns <- sub(pattern, "\\1", matches)
  unique(fns)
}

#' Detekter API-drift-moenstre i stderr
detect_api_drift <- function(stderr) {
  if (length(stderr) == 0) return(FALSE)
  text <- paste(stderr, collapse = "\n")
  patterns <- c(
    "unused argument",
    "argument .* is missing, with no default",
    "formal argument .* matched by multiple",
    "unknown parameter"
  )
  any(vapply(patterns, function(p) grepl(p, text), logical(1)))
}

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Koer een testfil i isoleret subproces via processx
#'
#' Starter en Rscript-subproces der loader biSPCharts via pkgload::load_all()
#' og koerer testthat::test_file(). stdout/stderr fanges separat.
#' Timeout haandteres af processx.
#'
#' @param file Sti til testfil
#' @param timeout Sekunder (default 60)
#' @param pkg_root Sti til biSPCharts repo root
#' @return list med exit_code, stdout, stderr, elapsed_s, timed_out
run_test_file_isolated <- function(file, timeout = 60, pkg_root = getwd()) {
  start_time <- Sys.time()

  r_code <- sprintf(
    paste0(
      'setwd("%s"); ',
      'pkgload::load_all(quiet = TRUE); ',
      'res <- testthat::test_file("%s", reporter = testthat::SilentReporter$new(), stop_on_failure = FALSE); ',
      'df <- as.data.frame(res); ',
      # df$error er logical: TRUE naar en test fejler med en uhandteret fejl (fx "could not find function").
      # Disse taeller som failures, men fremgaar ikke af df$failed.
      'n_err <- if ("error" %%in%% names(df)) sum(as.logical(df$error), na.rm = TRUE) else 0L; ',
      'n_total_fail <- sum(df$failed) + n_err; ',
      'cat(sprintf("[ FAIL %%d | WARN %%d | SKIP %%d | PASS %%d ]\\n", n_total_fail, sum(df$warning, na.rm = TRUE), sum(df$skipped), sum(df$passed))); ',
      # Udskriv fejlbeskeder fra error-tests via res-objektet (ikke df) saa extract_missing_functions() kan parse dem fra stderr
      'if (n_err > 0) { for (test_result in res) { for (exp in test_result$results) { if (inherits(exp, "expectation_error")) message(conditionMessage(exp)) } } }'
    ),
    pkg_root, file
  )

  result <- tryCatch({
    processx::run(
      command = file.path(R.home("bin"), "Rscript"),
      args = c("-e", r_code),
      timeout = timeout,
      error_on_status = FALSE
    )
  }, system_command_timeout_error = function(e) {
    list(status = 124L, stdout = "", stderr = "TIMEOUT", timeout = TRUE)
  }, error = function(e) {
    list(status = 1L, stdout = "", stderr = as.character(e$message), timeout = FALSE)
  })

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  list(
    exit_code = as.integer(result$status %||% 1L),
    stdout = strsplit(result$stdout %||% "", "\n", fixed = TRUE)[[1]],
    stderr = strsplit(result$stderr %||% "", "\n", fixed = TRUE)[[1]],
    elapsed_s = elapsed,
    timed_out = isTRUE(result$timeout)
  )
}
