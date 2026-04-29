# utils_csv_delimiter_detection.R
# Delt CSV-delimiter-detektion brugt af validator og parser.
#
# Spejler parser-kaskaden i fct_file_parse_pure.R:
#   1. Semikolon (dansk standard)
#   2. Auto-detect (readr, decimal_mark = ",")
#   3. Komma (engelsk standard)
#
# En fil er "parseable" hvis mindst én strategi giver >= 2 kolonner og > 0 rækker.
#
# @noRd

#' Forsøg at parse CSV og returner parsebarhed + metadata
#'
#' @param path Character(1) - sti til CSV-fil
#' @param encoding Character(1) - encoding (default "UTF-8")
#' @param n_max Integer(1) - maksimalt antal rækker til læsning (default 5)
#' @return Liste med:
#'   - `parseable` (logical) - TRUE hvis mindst én strategi lykkedes
#'   - `strategy` (character) - navn på successkabende strategi, eller NA
#'   - `delimiter` (character) - detekteret delimiter (";", ",", "\t", eller NA)
#'   - `ncol` (integer) - antal kolonner (0 hvis ingen strategi lykkedes)
#'   - `nrow` (integer) - antal data-rækker (0 hvis ingen strategi lykkedes)
#' @noRd
detect_csv_delimiter <- function(path, encoding = "UTF-8", n_max = 5L) {
  stopifnot(is.character(path), length(path) == 1L, nzchar(path))

  strategies <- list(
    list(
      name = "semikolon",
      delimiter = ";",
      fn = function() {
        readr::read_csv2(
          path,
          locale = readr::locale(decimal_mark = ",", grouping_mark = ".", encoding = encoding),
          n_max = n_max,
          show_col_types = FALSE,
          progress = FALSE
        )
      }
    ),
    list(
      name = "auto-detect",
      delimiter = NA_character_, # Lader readr bestemme
      fn = function() {
        readr::read_delim(
          path,
          delim = NULL,
          locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
          n_max = n_max,
          show_col_types = FALSE,
          trim_ws = TRUE,
          progress = FALSE
        )
      }
    ),
    list(
      name = "komma",
      delimiter = ",",
      fn = function() {
        readr::read_csv(
          path,
          locale = readr::locale(decimal_mark = ".", grouping_mark = ",", encoding = encoding),
          n_max = n_max,
          show_col_types = FALSE,
          progress = FALSE
        )
      }
    )
  )

  for (s in strategies) {
    result <- tryCatch(
      suppressWarnings(s$fn()),
      error = function(e) NULL
    )
    if (!is.null(result) && ncol(result) >= 2 && nrow(result) >= 1) {
      # Forsøg at aflæse faktisk delimiter fra auto-detect
      delim_used <- s$delimiter
      if (is.na(delim_used)) {
        # Prøv at aflæse delimiter fra spec-attribut
        spec <- attr(result, "spec")
        if (!is.null(spec) && !is.null(spec$delim)) {
          delim_used <- spec$delim
        }
      }
      return(list(
        parseable = TRUE,
        strategy  = s$name,
        delimiter = delim_used,
        ncol      = ncol(result),
        nrow      = nrow(result)
      ))
    }
  }

  list(
    parseable = FALSE,
    strategy  = NA_character_,
    delimiter = NA_character_,
    ncol      = 0L,
    nrow      = 0L
  )
}
