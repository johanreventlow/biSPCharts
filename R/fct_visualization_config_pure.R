# fct_visualization_config_pure.R
# Pure domænelogik til visualiserings-konfiguration — ingen Shiny-afhængigheder
# Returnerer VisualizationConfig S3-struktur.

#' Byg visualiserings-konfiguration (pure)
#'
#' Beregner den aktive kolonnekonfiguration til SPC-visualisering baseret på
#' manuelle bruger-overrides, auto-detektion og kolonne-mappings — i prioriteret rækkefølge.
#' Ingen Shiny-afhængigheder — kan unit-testes uden aktiv session.
#'
#' Prioriteringsrækkefølge (højeste vinder):
#' 1. `user_overrides` (eksplicitte brugervalg fra UI-input)
#' 2. `autodetect` (AutodetectResult fra run_autodetect)
#' 3. `mappings` (kolonne-mappings fra app_state, fx ved session-restore)
#'
#' @param data Data.frame eller NULL — bruges til validering af kolonnenavne
#' @param autodetect `AutodetectResult` eller NULL
#' @param user_overrides Liste med valgfrie bruger-overrides:
#'   - `x_col`, `y_col`, `n_col`: Character eller NULL
#'   - `chart_type`: Character (qic-format, fx `"run"`, `"p"`, `"c"`)
#'   - `mappings`: Liste med `x_column`, `y_column`, `n_column` fra app_state
#' @return `VisualizationConfig` S3-objekt eller NULL hvis ingen y_col kan bestemmes
#' @noRd
build_visualization_config <- function(data = NULL, autodetect = NULL, user_overrides = NULL) {
  overrides <- user_overrides %||% list()
  mappings <- overrides$mappings %||% list()

  # Hjælpefunktion: vælg første ikke-NULL og ikke-tom værdi
  pick_first <- function(...) {
    for (val in list(...)) {
      if (!is.null(val) && nzchar(as.character(val))) {
        return(as.character(val))
      }
    }
    NULL
  }

  # Y-kolonne bestemmes af prioritet 1→2→3
  y_col_manual <- overrides$y_col
  y_col_auto <- if (!is.null(autodetect)) autodetect$y_col else NULL
  y_col_mapping <- mappings$y_column

  y_col <- pick_first(y_col_manual, y_col_auto, y_col_mapping)

  # Hvis ingen y_col kan bestemmes, returnerer vi NULL
  if (is.null(y_col)) {
    return(NULL)
  }

  x_col <- pick_first(
    overrides$x_col,
    if (!is.null(autodetect)) autodetect$x_col else NULL,
    mappings$x_column
  )
  n_col <- pick_first(
    overrides$n_col,
    if (!is.null(autodetect)) autodetect$n_col else NULL,
    mappings$n_column
  )

  chart_type <- overrides$chart_type %||% "run"

  # Valider at fundne kolonner rent faktisk eksisterer i data
  source_label <- "manual"
  if (!is.null(y_col_manual)) {
    source_label <- "manual"
  } else if (!is.null(y_col_auto)) {
    source_label <- "autodetect"
  } else {
    source_label <- "mapping"
  }

  if (!is.null(data)) {
    col_names <- names(data)
    if (!is.null(x_col) && !x_col %in% col_names) x_col <- NULL
    if (!is.null(y_col) && !y_col %in% col_names) {
      return(NULL) # y_col er kritisk — returner NULL
    }
    if (!is.null(n_col) && !n_col %in% col_names) n_col <- NULL
  }

  new_visualization_config(
    x_col      = x_col,
    y_col      = y_col,
    n_col      = n_col,
    chart_type = chart_type,
    source     = source_label
  )
}

#' Konstruér VisualizationConfig S3-objekt
#' @noRd
new_visualization_config <- function(x_col, y_col, n_col, chart_type, source) {
  structure(
    list(
      x_col      = x_col,
      y_col      = y_col,
      n_col      = n_col,
      chart_type = chart_type,
      source     = source
    ),
    class = "VisualizationConfig"
  )
}

#' Print-metode for VisualizationConfig
#'
#' @param x VisualizationConfig-objekt.
#' @param ... Ignoreres.
#' @export
print.VisualizationConfig <- function(x, ...) {
  cat(sprintf(
    "VisualizationConfig [%s]\n  x=%s  y=%s  n=%s  chart=%s\n",
    x$source,
    x$x_col %||% "NULL",
    x$y_col %||% "NULL",
    x$n_col %||% "NULL",
    x$chart_type
  ))
  invisible(x)
}
