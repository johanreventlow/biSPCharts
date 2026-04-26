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

#' Tael assertions per fil
#'
#' Tæller alle expect_*-kald i en fil via AST-parsing.
#' Udkommenterede kald ignoreres naturligt.
#'
#' @param file Sti til R-fil
#' @return Integer: antal expect_*-kald
count_assertions <- function(file) {
  parsed <- tryCatch(
    parse(file, keep.source = TRUE),
    error = function(e) NULL
  )
  if (is.null(parsed) || length(parsed) == 0) return(0L)

  pd <- utils::getParseData(parsed)
  if (is.null(pd) || nrow(pd) == 0) return(0L)

  calls <- pd$text[pd$token == "SYMBOL_FUNCTION_CALL"]
  sum(grepl("^expect_", calls))
}

#' Rapportér top N filer med flest skip()-kald
#'
#' Returnerer en data.frame sorteret faldende på antal skip-kald.
#'
#' @param test_dir Sti til testthat-mappe
#' @param n Top-N filer (default: 5)
#' @return data.frame med kolonner: file, n_skips
top_files_by_skips <- function(test_dir = "tests/testthat", n = 5L) {
  files <- scan_test_files(test_dir)

  skip_counts <- vapply(files, function(file) {
    parsed <- tryCatch(
      parse(file, keep.source = TRUE),
      error = function(e) NULL
    )
    if (is.null(parsed) || length(parsed) == 0) return(0L)

    pd <- utils::getParseData(parsed)
    if (is.null(pd) || nrow(pd) == 0) return(0L)

    calls <- pd$text[pd$token == "SYMBOL_FUNCTION_CALL"]
    sum(calls %in% c("skip", "skip_on_ci", "skip_if", "skip_if_not",
      "skip_if_not_installed", "skip_on_cran"))
  }, integer(1))

  result <- data.frame(
    file = basename(files),
    n_skips = skip_counts,
    stringsAsFactors = FALSE
  )

  result <- result[order(-result$n_skips), ]
  head(result, n)
}

#' Rapportér top N filer med færrest assertions per test_that-blok
#'
#' Beregner assertions/test_that ratio per fil og sorterer stigende
#' (lav ratio = potentielt svage tests).
#'
#' @param test_dir Sti til testthat-mappe
#' @param n Top-N filer (default: 5)
#' @return data.frame med kolonner: file, n_assertions, n_blocks, ratio
top_files_by_low_assertion_ratio <- function(test_dir = "tests/testthat", n = 5L) {
  files <- scan_test_files(test_dir)

  rows <- lapply(files, function(file) {
    n_assert <- count_assertions(file)
    n_blocks <- count_test_blocks(file)

    ratio <- if (n_blocks > 0) round(n_assert / n_blocks, 2) else NA_real_

    data.frame(
      file = basename(file),
      n_assertions = n_assert,
      n_blocks = n_blocks,
      ratio = ratio,
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)

  # Sortér stigende på ratio (laveste = svageste tests)
  # Filer med 0 blokke (NA ratio) sorteres sidst
  result <- result[order(is.na(result$ratio), result$ratio), ]
  # Filtrer filer med mindst 1 blok for at undgå tomme filer
  result <- result[!is.na(result$ratio) & result$n_blocks > 0, ]
  head(result, n)
}

#' Print audit rapport section: Phase 6 metrics
#'
#' Printer top-5 skip-filer og top-5 lav-assertion-ratio filer til stdout.
#'
#' @param test_dir Sti til testthat-mappe
print_phase6_audit <- function(test_dir = "tests/testthat") {
  cat("\n=== Phase 6 Audit: Skip-inventory og Assertion-ratio ===\n\n")

  cat("Top 5 filer med flest skip()-kald:\n")
  skip_top <- top_files_by_skips(test_dir, n = 5L)
  for (i in seq_len(nrow(skip_top))) {
    cat(sprintf("  %2d. %-60s %d skips\n",
      i, skip_top$file[i], skip_top$n_skips[i]))
  }

  cat("\nTop 5 filer med færrest assertions per test_that-blok:\n")
  ratio_top <- top_files_by_low_assertion_ratio(test_dir, n = 5L)
  for (i in seq_len(nrow(ratio_top))) {
    cat(sprintf("  %2d. %-60s %.2f assertions/blok (%d assert, %d blokke)\n",
      i, ratio_top$file[i], ratio_top$ratio[i],
      ratio_top$n_assertions[i], ratio_top$n_blocks[i]))
  }

  cat("\n")
  invisible(list(top_skips = skip_top, low_assertion_ratio = ratio_top))
}
