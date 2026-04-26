# ==============================================================================
# AUDIT: Statisk analyse af testfiler (#203)
# ==============================================================================

#' Ekstraher alle funktionsnavne der kaldes i en R-fil
#'
#' Bruger utils::getParseData() til at parse AST og hente tokens af type
#' SYMBOL_FUNCTION_CALL. Udkommenterede kald ignoreres naturligt (ikke del
#' af parse-traeet).
#'
#' @param file Sti til R-fil
#' @return Character vector af unikke funktionsnavne
extract_function_calls <- function(file) {
  parsed <- tryCatch(
    parse(file, keep.source = TRUE),
    error = function(e) NULL
  )
  if (is.null(parsed) || length(parsed) == 0) return(character(0))

  pd <- utils::getParseData(parsed)
  if (is.null(pd) || nrow(pd) == 0) return(character(0))

  calls <- pd$text[pd$token == "SYMBOL_FUNCTION_CALL"]
  unique(calls)
}

#' Tael aktive test_that og it-blokke
#'
#' Udkommenterede blokke ignoreres da de ikke er del af parse-traeet.
#' Returnerer antal kald (ikke unikke navne) ved at parse AST direkte.
count_test_blocks <- function(file) {
  parsed <- tryCatch(
    parse(file, keep.source = TRUE),
    error = function(e) NULL
  )
  if (is.null(parsed) || length(parsed) == 0) return(0L)

  pd <- utils::getParseData(parsed)
  if (is.null(pd) || nrow(pd) == 0) return(0L)

  calls <- pd$text[pd$token == "SYMBOL_FUNCTION_CALL"]
  sum(calls %in% c("test_that", "it"))
}

#' Detekter deprecation-marker oeverst i testfil
#'
#' Matcher regex ^#\\s*DEPRECATED paa foerste 10 linjer.
detect_deprecation_marker <- function(file) {
  if (!file.exists(file)) return(FALSE)
  lines <- readLines(file, n = 10, warn = FALSE)
  any(grepl("^#\\s*DEPRECATED", lines, ignore.case = TRUE))
}

#' Find alle testfiler i en mappe
#'
#' Matcher kun filer der starter med test- og slutter med .R.
scan_test_files <- function(dir = "tests/testthat") {
  list.files(
    dir,
    pattern = "^test-.*\\.R$",
    full.names = TRUE,
    recursive = FALSE
  )
}

#' Liste af funktioner i biSPCharts namespace
list_r_exports <- function() {
  if (!"biSPCharts" %in% loadedNamespaces()) {
    pkgload::load_all(quiet = TRUE)
  }
  ns <- asNamespace("biSPCharts")
  names <- ls(envir = ns, all.names = FALSE)
  fns <- names[vapply(names, function(n) is.function(get(n, envir = ns)), logical(1))]
  fns
}

#' Tael LOC i fil
count_loc <- function(file) {
  if (!file.exists(file)) return(0L)
  length(readLines(file, warn = FALSE))
}

# ==============================================================================
# PHASE 6 ADDITIONS (Issue #322): Assertions per fil, skip-top5, assertion-ratio
# ==============================================================================

# Returnerer vektor af function-call-navne fra fil, eller character(0) ved fejl.
get_function_calls <- function(file) {
  parsed <- tryCatch(
    parse(file, keep.source = TRUE),
    error = function(e) NULL
  )
  if (is.null(parsed) || length(parsed) == 0) return(character(0))
  pd <- utils::getParseData(parsed)
  if (is.null(pd) || nrow(pd) == 0) return(character(0))
  pd$text[pd$token == "SYMBOL_FUNCTION_CALL"]
}

SKIP_FN_NAMES <- c("skip", "skip_on_ci", "skip_if", "skip_if_not",
  "skip_if_not_installed", "skip_on_cran")

#' Tael assertions per fil
#'
#' @param file Sti til R-fil
#' @return Integer: antal expect_*-kald
count_assertions <- function(file) {
  sum(grepl("^expect_", get_function_calls(file)))
}

#' Saml alle Phase-6-metrikker i ét pas over testfiler
#'
#' @param test_dir Sti til testthat-mappe
#' @return data.frame med kolonner: file, n_assertions, n_blocks, n_skips, ratio
collect_phase6_metrics <- function(test_dir = "tests/testthat") {
  files <- scan_test_files(test_dir)

  rows <- lapply(files, function(file) {
    calls    <- get_function_calls(file)
    n_assert <- sum(grepl("^expect_", calls))
    n_skips  <- sum(calls %in% SKIP_FN_NAMES)
    n_blocks <- count_test_blocks(file)
    ratio    <- if (n_blocks > 0) round(n_assert / n_blocks, 2) else NA_real_

    data.frame(
      file = basename(file),
      n_assertions = n_assert,
      n_blocks = n_blocks,
      n_skips = n_skips,
      ratio = ratio,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Rapportér top N filer med flest skip()-kald
#'
#' @param test_dir Sti til testthat-mappe
#' @param n Top-N filer (default: 5)
#' @return data.frame med kolonner: file, n_skips
top_files_by_skips <- function(test_dir = "tests/testthat", n = 5L) {
  metrics <- collect_phase6_metrics(test_dir)
  result  <- metrics[order(-metrics$n_skips), c("file", "n_skips")]
  head(result, n)
}

#' Rapportér top N filer med færrest assertions per test_that-blok
#'
#' @param test_dir Sti til testthat-mappe
#' @param n Top-N filer (default: 5)
#' @return data.frame med kolonner: file, n_assertions, n_blocks, ratio
top_files_by_low_assertion_ratio <- function(test_dir = "tests/testthat", n = 5L) {
  metrics <- collect_phase6_metrics(test_dir)
  result  <- metrics[!is.na(metrics$ratio) & metrics$n_blocks > 0, ]
  result  <- result[order(result$ratio), c("file", "n_assertions", "n_blocks", "ratio")]
  head(result, n)
}

#' Print audit rapport section: Phase 6 metrics
#'
#' @param test_dir Sti til testthat-mappe
print_phase6_audit <- function(test_dir = "tests/testthat") {
  cat("\n=== Phase 6 Audit: Skip-inventory og Assertion-ratio ===\n\n")
  metrics <- collect_phase6_metrics(test_dir)

  skip_top  <- head(metrics[order(-metrics$n_skips), ], 5L)
  ratio_top <- head(
    metrics[!is.na(metrics$ratio) & metrics$n_blocks > 0, ][
      order(metrics$ratio[!is.na(metrics$ratio) & metrics$n_blocks > 0]), ],
    5L
  )

  cat("Top 5 filer med flest skip()-kald:\n")
  for (i in seq_len(nrow(skip_top))) {
    cat(sprintf("  %2d. %-60s %d skips\n",
      i, skip_top$file[i], skip_top$n_skips[i]))
  }

  cat("\nTop 5 filer med færrest assertions per test_that-blok:\n")
  for (i in seq_len(nrow(ratio_top))) {
    cat(sprintf("  %2d. %-60s %.2f assertions/blok (%d assert, %d blokke)\n",
      i, ratio_top$file[i], ratio_top$ratio[i],
      ratio_top$n_assertions[i], ratio_top$n_blocks[i]))
  }

  cat("\n")
  invisible(list(top_skips = skip_top, low_assertion_ratio = ratio_top))
}
