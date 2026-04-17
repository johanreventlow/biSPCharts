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
