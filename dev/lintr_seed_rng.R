# ==============================================================================
# lintr_seed_rng.R
# ==============================================================================
# §3.2.1 af harden-test-suite-regression-gate openspec change.
#
# Custom lintr-regel: seed_rng_linter()
#
# Flagger kald til tilfældigheds-funktioner (rnorm, runif, sample, rpois,
# rbinom, rexp, rgamma, rbeta, rt, rchisq) der ikke er beskyttet af
# set.seed() eller withr::with_seed() i samme test_that()-blok.
#
# Formål: Sikre deterministiske tests. Ubeskyttede rng-kald producerer
# flaky tests der fejler på tilfældig seed.
#
# Dette linter er test-scope (kun tests/testthat/ bør have rng-kald uden
# seed i produktions-R-filer bør det være en design-beslutning).
#
# Usage i .lintr:
#   source("dev/lintr_seed_rng.R")
#   linters: linters_with_defaults(
#     seed_rng_linter = seed_rng_linter()
#   )
# ==============================================================================

#' Linter: detekter rng-kald uden set.seed i test_that-blokke
#'
#' @return En `lintr::Linter`-funktion.
#' @export
seed_rng_linter <- function() {
  # Random-funktioner der kræver seeding
  rng_functions <- c(
    "rnorm", "runif", "sample", "rpois", "rbinom",
    "rexp", "rgamma", "rbeta", "rt", "rchisq", "rcauchy"
  )

  # Seed-etablerende funktioner
  seed_functions <- c(
    "set.seed",
    "with_seed", "withr::with_seed"
  )

  lintr::Linter(function(source_expression) {
    if (is.null(source_expression$parsed_content)) {
      return(list())
    }

    pd <- source_expression$parsed_content
    lints <- list()

    # Hver source_expression er én top-level R-statement. Hvis den er en
    # test_that/it-blok, betragter vi hele expression'en som én
    # seed-context. Derfor:
    #   1) Er dette en test_that/it-blok?
    #   2) Indeholder blokken set.seed/with_seed?
    #   3) Hvis ikke: flag hvert rng-kald.

    calls <- pd[pd$token == "SYMBOL_FUNCTION_CALL", , drop = FALSE]
    if (nrow(calls) == 0) {
      return(list())
    }

    is_test_block <- any(calls$text %in% c("test_that", "it"))
    if (!is_test_block) {
      return(list())
    }

    has_seed <- any(calls$text %in% c("set.seed", "with_seed"))
    if (has_seed) {
      return(list()) # Seed etableret — alle rng-kald i blokken OK
    }

    rng_rows <- which(calls$text %in% rng_functions)

    for (rng_idx in rng_rows) {
      lint_line <- calls$line1[rng_idx]
      # source_expression$lines er named character (navne = linje-nr som str)
      line_text <- source_expression$lines[as.character(lint_line)]
      if (is.na(line_text) || is.null(line_text)) line_text <- ""

      lints[[length(lints) + 1L]] <- lintr::Lint(
        filename = source_expression$filename,
        line_number = lint_line,
        column_number = calls$col1[rng_idx],
        type = "warning",
        message = sprintf(
          paste0(
            "Rng-kald '%s()' uden set.seed() eller withr::with_seed() ",
            "i test_that — flaky test"
          ),
          calls$text[rng_idx]
        ),
        line = as.character(line_text)
      )
    }

    lints
  })
}
