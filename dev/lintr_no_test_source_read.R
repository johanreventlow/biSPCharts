# ==============================================================================
# lintr_no_test_source_read.R
# ==============================================================================
# Cycle F H2 + M3 (Codex peer-review 2026-05-09).
#
# Custom lintr-regel: no_test_source_read_linter()
#
# Flagger source-tree-reads i test-filer der virker i devtools::test() men
# fejler (eller silent-skipper) i R CMD check fordi pakken installeres uden
# plain .R-filer i source-tree-layout.
#
# Pattern A (direkte): readLines(test_path("..", "..", "R", "foo.R"))
# Pattern B (variable): src <- test_path("..", "..", "R", ...); readLines(src)
# Pattern C (hardcoded): readLines("../../R/foo.R")
#
# Korrekt alternativ: paste(deparse(body(funktion)), collapse = "\n")
# Virker BAADE i devtools::test og R CMD check fordi den opererer paa
# loaded function-bodies, ej paa filsystem.
#
# Heuristik: flag hvis source_expression indeholder BAADE
#   - et test_path()-kald med ".." i argumenterne (= escape-fra-tests/), ELLER
#     en STR_CONST der matcher "../R/" eller "../../R/", OG
#   - et read*-kald (readLines, readRDS, read.csv, scan, etc)
#
# Trade-offs:
#   + Fanger pattern A, B, C uden compleks variable-flow-tracking
#   + Faa false positives (test_path("fixtures", ...) ej flagged)
#   - Edge case: test_path("..", ...) brugt til non-read-formaal i samme
#     test_that-blok som en separat readLines() vil give false-positive.
#     Workaround: # nolint: no_test_source_read_linter
#
# Historik: PR #669, #675 fixede 2 instanser af pattern A. M3 (Codex 2026-05-09)
# afsloerede 3. instans (test-navigation-no-double-emit.R) som brugte pattern B
# under skip_if_not-cover -> silent-skip i R CMD check, false confidence i CI.
#
# Usage i .lintr:
#   linter_path <- file.path(getwd(), "dev", "lintr_no_test_source_read.R")
#   sys.source(linter_path, envir = environment())
#   custom$no_test_source_read_linter <- no_test_source_read_linter()
# ==============================================================================

#' Linter: detekter source-tree-reads i test-filer
#'
#' @return En `lintr::Linter`-funktion.
#' @noRd
no_test_source_read_linter <- function() {
  read_functions <- c("readLines", "readRDS", "read.csv", "read.dcf", "scan",
                       "read.table", "read.delim")
  path_functions <- c("test_path")  # `testthat::test_path` matcher ogsaa via .text

  lintr::Linter(function(source_expression) {
    if (is.null(source_expression$parsed_content)) {
      return(list())
    }

    pd <- source_expression$parsed_content
    lints <- list()

    calls <- pd[pd$token == "SYMBOL_FUNCTION_CALL", , drop = FALSE]
    if (nrow(calls) == 0) {
      return(list())
    }

    # Find ALLE read*-kald
    read_calls <- calls[calls$text %in% read_functions, , drop = FALSE]
    if (nrow(read_calls) == 0) {
      return(list())
    }

    # Tjek om source_expression indeholder source-tree-escape-markers:
    #   1) test_path() med ".." som STR_CONST-arg
    #   2) STR_CONST der matcher hardcoded "../R/" eller "../../R/"
    test_path_calls <- calls[calls$text %in% path_functions, , drop = FALSE]
    has_escape_test_path <- FALSE
    if (nrow(test_path_calls) > 0) {
      str_consts <- pd[pd$token == "STR_CONST", , drop = FALSE]
      # Hvis ANY STR_CONST = '".."' → escape-markedinger
      has_escape_test_path <- any(str_consts$text == '".."') ||
                              any(str_consts$text == "'..'")
    }

    str_consts <- pd[pd$token == "STR_CONST", , drop = FALSE]
    has_hardcoded_path <- FALSE
    if (nrow(str_consts) > 0) {
      # Match "../R/..." eller "../../R/..." i string-literals
      has_hardcoded_path <- any(grepl("\\.\\./[^\"']*R/|\\.\\./\\.\\./R/",
                                       str_consts$text))
    }

    if (!has_escape_test_path && !has_hardcoded_path) {
      return(list())
    }

    # Flag hvert read*-kald i denne expression
    for (i in seq_len(nrow(read_calls))) {
      read_line <- read_calls$line1[i]
      read_col <- read_calls$col1[i]
      read_func <- read_calls$text[i]

      line_text <- source_expression$lines[as.character(read_line)]
      if (is.na(line_text) || is.null(line_text)) line_text <- ""

      detail <- if (has_escape_test_path) {
        "test_path(\"..\", ...) escape-pattern fundet i samme expression"
      } else {
        "hardcoded ../R/-path fundet i samme expression"
      }

      msg <- sprintf(
        paste0(
          "'%s()' kombineret med source-tree-escape-pattern (%s). ",
          "Virker i devtools::test() men fejler/skipper i R CMD check ",
          "fordi pakken installeres uden plain .R-filer. Brug i stedet: ",
          "paste(deparse(body(funktion)), collapse = \"\\n\")"
        ),
        read_func, detail
      )

      lints[[length(lints) + 1L]] <- lintr::Lint(
        filename = source_expression$filename,
        line_number = read_line,
        column_number = read_col,
        type = "warning",
        message = msg,
        line = as.character(line_text)
      )
    }

    lints
  })
}
