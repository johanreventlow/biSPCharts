# fct_autodetect_pure.R
# Pure domænelogik til kolonne-auto-detektion — ingen Shiny-afhængigheder
# Returnerer AutodetectResult S3-struktur.

#' Auto-detekter kolonneroller i data (pure)
#'
#' Analyserer en data.frame og returnerer bedste bud på X/Y/N/Skift/Frys/Kommentar
#' kolonner. Ingen Shiny-afhængigheder — kan unit-testes uden aktiv session.
#'
#' Guard-logik (in_progress, frozen_until_next_trigger) og caching forbliver
#' i `autodetect_engine()` shim.
#'
#' @param data Data.frame der skal analyseres, eller NULL for navn-baseret detektion
#' @param hints Liste med valgfrie hints:
#'   - `col_names`: Character vector med kolonnenavne (bruges hvis `data` er NULL)
#'   - `prefer_name_based`: Logical — tving navn-baseret detektion (default FALSE)
#' @return `AutodetectResult` S3-objekt
#' @noRd
run_autodetect <- function(data = NULL, hints = NULL) {
  hints <- hints %||% list()

  use_name_based <- isTRUE(hints$prefer_name_based) || is.null(data) || nrow(data) == 0

  if (use_name_based) {
    col_names <- hints$col_names %||%
      (if (!is.null(data)) names(data) else character(0))
    raw <- detect_columns_name_based(col_names, app_state = NULL)
  } else {
    raw <- detect_columns_full_analysis(data, app_state = NULL)
  }

  new_autodetect_result(raw)
}

#' Konstruér AutodetectResult S3-objekt
#' @noRd
new_autodetect_result <- function(raw) {
  structure(
    list(
      x_col = raw$x_col,
      y_col = raw$y_col,
      n_col = raw$n_col,
      skift_col = raw$skift_col,
      frys_col = raw$frys_col,
      kommentar_col = raw$kommentar_col,
      scores = raw[setdiff(names(raw), c(
        "x_col", "y_col", "n_col", "skift_col", "frys_col", "kommentar_col"
      ))],
      timestamp = Sys.time()
    ),
    class = "AutodetectResult"
  )
}

#' Print-metode for AutodetectResult
#'
#' @param x AutodetectResult-objekt.
#' @param ... Ignoreres.
#' @export
print.AutodetectResult <- function(x, ...) {
  cat(sprintf(
    "AutodetectResult [%s]\n  x=%s  y=%s  n=%s  skift=%s  frys=%s\n",
    format(x$timestamp, "%H:%M:%S"),
    x$x_col %||% "NULL",
    x$y_col %||% "NULL",
    x$n_col %||% "NULL",
    x$skift_col %||% "NULL",
    x$frys_col %||% "NULL"
  ))
  invisible(x)
}
