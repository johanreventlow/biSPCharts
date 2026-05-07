# fct_spc_contracts.R
# S3-kontrakter for SPC pipeline-helpers.
#
# Disse typer definerer grænsefladerne mellem pipeline-trin:
#   validate_spc_request()  → spc_request
#   prepare_spc_data()      → spc_prepared
#   resolve_axis_units()    → spc_axes

# ---------------------------------------------------------------------------
# spc_request
# ---------------------------------------------------------------------------

#' Konstruer et valideret SPC-anmodnings-objekt
#'
#' Returneret af `validate_spc_request()` — repræsenterer input der har
#' bestået alle validerings-checks.
#'
#' @param data data.frame med mindst 3 rækker.
#' @param x_var character. Kolonne-navn for x-aksen (dato/sekvens).
#' @param y_var character. Kolonne-navn for måle-kolonnen.
#' @param chart_type character. Valideret chart-type (lowercase, fx "run", "p").
#' @param n_var character eller NULL. Kolonne-navn for nævner (krævet for p, u).
#' @param cl_var character eller NULL. Kolonne-navn for manuel centerlinje.
#' @param freeze_var character eller NULL. Kolonne-navn for freeze-grænse.
#' @param part_var character eller NULL. Kolonne-navn for fase-opdeling.
#' @param notes_column character eller NULL. Kolonne-navn for noter.
#' @param multiply numeric. Multiplikator for y-akse (default 1).
#' @param options list. Ekstra parametre (target_value, y_axis_unit, osv.).
#'
#' @return S3-objekt af klassen `c("spc_request", "list")`.
#' @keywords internal
new_spc_request <- function(
  data,
  x_var,
  y_var,
  chart_type,
  n_var = NULL,
  cl_var = NULL,
  freeze_var = NULL,
  part_var = NULL,
  notes_column = NULL,
  multiply = 1,
  options = list()
) {
  structure(
    list(
      data = data,
      x_var = x_var,
      y_var = y_var,
      chart_type = chart_type,
      n_var = n_var,
      cl_var = cl_var,
      freeze_var = freeze_var,
      part_var = part_var,
      notes_column = notes_column,
      multiply = multiply,
      options = options
    ),
    class = c("spc_request", "list")
  )
}

#' @export
print.spc_request <- function(x, ...) { # S3 print-metode — cat() er idiomatisk
  cat(
    sprintf(
      "<spc_request> chart_type=%s x=%s y=%s n=%s rows=%d\n",
      x$chart_type,
      x$x_var,
      x$y_var,
      x$n_var %||% "NULL",
      nrow(x$data)
    )
  )
  invisible(x)
}

# ---------------------------------------------------------------------------
# spc_prepared
# ---------------------------------------------------------------------------

#' Konstruer et forberedt SPC-datasæt
#'
#' Returneret af `prepare_spc_data()` — data er filtreret, datoer parsede
#' og numeriske værdier validerede.
#'
#' @param data data.frame. Filtreret og numerisk-parsede data.
#' @param x_var character. Kolonne-navn for x.
#' @param y_var character. Kolonne-navn for y (numerisk efter parsing).
#' @param chart_type character. Valideret chart-type.
#' @param n_var character eller NULL.
#' @param cl_var character eller NULL.
#' @param freeze_var character eller NULL.
#' @param part_var character eller NULL.
#' @param notes_column character eller NULL.
#' @param multiply numeric.
#' @param options list.
#' @param n_rows_original integer. Rækkeantal i original data.
#' @param n_rows_filtered integer. Rækkeantal efter filtrering.
#'
#' @return S3-objekt af klassen `c("spc_prepared", "list")`.
#' @keywords internal
new_spc_prepared <- function(
  data,
  x_var,
  y_var,
  chart_type,
  n_var = NULL,
  cl_var = NULL,
  freeze_var = NULL,
  part_var = NULL,
  notes_column = NULL,
  multiply = 1,
  options = list(),
  n_rows_original = nrow(data),
  n_rows_filtered = nrow(data)
) {
  structure(
    list(
      data = data,
      x_var = x_var,
      y_var = y_var,
      chart_type = chart_type,
      n_var = n_var,
      cl_var = cl_var,
      freeze_var = freeze_var,
      part_var = part_var,
      notes_column = notes_column,
      multiply = multiply,
      options = options,
      n_rows_original = n_rows_original,
      n_rows_filtered = n_rows_filtered
    ),
    class = c("spc_prepared", "list")
  )
}

#' @export
print.spc_prepared <- function(x, ...) { # S3 print-metode — cat() er idiomatisk
  cat(
    sprintf(
      "<spc_prepared> chart_type=%s x=%s y=%s rows=%d (filtreret fra %d)\n",
      x$chart_type,
      x$x_var,
      x$y_var,
      x$n_rows_filtered,
      x$n_rows_original
    )
  )
  invisible(x)
}

# ---------------------------------------------------------------------------
# spc_axes
# ---------------------------------------------------------------------------

#' Konstruer en aksekonfiguration for SPC-rendering
#'
#' Returneret af `resolve_axis_units()` — indeholder skaleret target/centerline
#' og BFHcharts-kompatibel y_axis_unit.
#'
#' @param y_axis_unit character. BFHcharts-kompatibel enhed ("count", "percent",
#'   "rate", "time").
#' @param multiply numeric. Effektiv multiplikator for y-akse.
#' @param target_value numeric eller NULL. Target-værdi skaleret til kanoniske
#'   enheder (minutter for tids-typer).
#' @param centerline_value numeric eller NULL. Manuel centerlinje (skaleret).
#' @param target_text character eller NULL. Formateret target-label til display.
#'
#' @return S3-objekt af klassen `c("spc_axes", "list")`.
#' @keywords internal
new_spc_axes <- function(
  y_axis_unit,
  multiply,
  target_value = NULL,
  centerline_value = NULL,
  target_text = NULL
) {
  structure(
    list(
      y_axis_unit = y_axis_unit,
      multiply = multiply,
      target_value = target_value,
      centerline_value = centerline_value,
      target_text = target_text
    ),
    class = c("spc_axes", "list")
  )
}

#' @export
print.spc_axes <- function(x, ...) { # S3 print-metode — cat() er idiomatisk
  cat(
    sprintf(
      "<spc_axes> unit=%s multiply=%g target=%s\n",
      x$y_axis_unit,
      x$multiply,
      if (is.null(x$target_value)) "NULL" else as.character(x$target_value)
    )
  )
  invisible(x)
}
