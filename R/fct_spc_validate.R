# fct_spc_validate.R
# Validerings-helper for SPC pipeline.

#' Valider SPC-anmodning og returnér et spc_request-objekt
#'
#' Tjekker alle obligatoriske parametre og data-egenskaber, og returnerer
#' et `spc_request` S3-objekt hvis input er gyldigt. Kaster `spc_input_error`
#' ved ugyldig input — fejl propagerer direkte til caller.
#'
#' @param data data.frame med SPC-data.
#' @param x_var character. Kolonne-navn for x-aksen.
#' @param y_var character. Kolonne-navn for måle-kolonnen.
#' @param chart_type character. SPC chart-type (fx "run", "p", "u").
#' @param n_var character eller NULL. Kolonne-navn for nævner.
#' @param cl_var character eller NULL. Manuel centerlinje-kolonne.
#' @param freeze_var character eller NULL. Freeze-grænse-kolonne.
#' @param part_var character eller NULL. Fase-opdeling-kolonne.
#' @param notes_column character eller NULL. Noter-kolonne.
#' @param multiply numeric. Multiplikator for y-akse (default 1).
#' @param ... Ekstra parametre videregivet som `options` i `spc_request`
#'   (fx `target_value`, `y_axis_unit`, `chart_title`).
#'
#' @return `spc_request` S3-objekt.
#' @keywords internal
validate_spc_request <- function(
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
  ...
) {
  # 1. data er påkrævet og skal være data.frame
  if (is.null(data)) {
    spc_abort(
      "data parameter er påkrævet (data required): må ikke være NULL",
      class = "spc_input_error"
    )
  }
  if (!is.data.frame(data)) {
    spc_abort("data skal være en data.frame", class = "spc_input_error")
  }

  # 2. x_var er påkrævet
  if (is.null(x_var) || !nzchar(trimws(x_var))) {
    spc_abort(
      "x_var parameter er påkrævet (x_var required): angiv kolonnenavn for x-aksen",
      class = "spc_input_error"
    )
  }

  # 3. y_var er påkrævet
  if (is.null(y_var) || !nzchar(trimws(y_var))) {
    spc_abort(
      "y_var parameter er påkrævet (y_var required): angiv kolonnenavn for målekolonnen",
      class = "spc_input_error"
    )
  }

  # 4. chart_type er påkrævet og skal normaliseres
  if (is.null(chart_type) || !nzchar(trimws(chart_type))) {
    spc_abort(
      "chart_type parameter er påkrævet (chart_type required)",
      class = "spc_input_error"
    )
  }
  ct_normalized <- tolower(trimws(chart_type))

  # 5. chart_type skal være en understøttet type
  if (!ct_normalized %in% SUPPORTED_CHART_TYPES_BFH) {
    spc_abort(
      paste0(
        "chart_type '", chart_type, "' er invalid (ugyldig diagramtype). ",
        "Must be one of: ",
        paste(SUPPORTED_CHART_TYPES_BFH, collapse = ", ")
      ),
      class = "spc_input_error"
    )
  }

  # 6. n_var er påkrævet for P-, U-kort (og pp, up)
  if (ct_normalized %in% c("p", "pp", "u", "up") && is.null(n_var)) {
    spc_abort(
      paste0(
        "n_var (denominator) required for ", ct_normalized, "-kort. ",
        "Angiv kolonnenavnet for nævneren."
      ),
      class = "spc_input_error"
    )
  }

  # 7. data må ikke være tom
  if (nrow(data) == 0) {
    spc_abort(
      "Ingen rækker fundet i data (empty dataset). Upload data først.",
      class = "spc_input_error"
    )
  }

  # 8. Mindst 3 datapunkter kræves
  if (nrow(data) < 3) {
    spc_abort(
      paste0(
        "For få datapunkter: ", nrow(data), " række(r) fundet (too few/insufficient). ",
        "minimum 3 datapunkter kræves for SPC-analyse."
      ),
      class = "spc_input_error"
    )
  }

  # 9. x_var og y_var skal eksistere som kolonner i data
  if (!x_var %in% names(data)) {
    spc_abort(
      paste0("X-kolonne '", x_var, "' blev ikke fundet i data (missing column: x_var)"),
      class = "spc_input_error"
    )
  }
  if (!y_var %in% names(data)) {
    spc_abort(
      paste0("Y-kolonne '", y_var, "' blev ikke fundet i data (missing column: y_var)"),
      class = "spc_input_error"
    )
  }
  if (!is.null(n_var) && !n_var %in% names(data)) {
    spc_abort(
      paste0("Nævner-kolonne '", n_var, "' blev ikke fundet i data (missing column: n_var)"),
      class = "spc_input_error"
    )
  }

  # 10. y_var må ikke udelukkende bestå af NA
  y_vals <- data[[y_var]]
  if (all(is.na(y_vals))) {
    spc_abort(
      paste0(
        "Kolonnen '", y_var, "' indeholder udelukkende NA-værdier. ",
        "Ingen komplette datapunkter til rådighed (all NA/no valid values)."
      ),
      class = "spc_input_error"
    )
  }

  # 11. y_var skal være numerisk (eller konverterbar — inkl. danske talformater)
  if (!is.numeric(y_vals)) {
    std_converted <- suppressWarnings(as.numeric(as.character(y_vals)))
    danish_converted <- suppressWarnings(as.numeric(gsub(",", ".", as.character(y_vals))))
    any_convertible <- !all(is.na(std_converted)) || !all(is.na(danish_converted))
    non_na_vals <- !all(is.na(y_vals))
    if (non_na_vals && !any_convertible) {
      spc_abort(
        paste0(
          "Kolonnen '", y_var, "' indeholder ikke-numeriske værdier og kan ikke konverteres (invalid/convert). ",
          "Kolonnen skal indeholde tal (også dansk talformat med komma accepteres)."
        ),
        class = "spc_input_error"
      )
    }
  }

  # 12. n_var må ikke indeholde nul-værdier for rate-baserede kort
  if (!is.null(n_var) && n_var %in% names(data) &&
    ct_normalized %in% c("p", "pp", "u", "up")) {
    n_vals <- data[[n_var]]
    n_numeric <- suppressWarnings(as.numeric(n_vals))
    if (all(is.na(n_numeric)) && is.character(n_vals)) {
      n_numeric <- suppressWarnings(as.numeric(gsub(",", ".", n_vals)))
    }
    if (any(!is.na(n_numeric) & n_numeric == 0)) {
      spc_abort(
        paste0(
          "Nævner-kolonnen '", n_var, "' indeholder nul-værdier. ",
          "Nævner må ikke være nul for ", toupper(ct_normalized), "-kort."
        ),
        class = "spc_input_error"
      )
    }
  }

  new_spc_request(
    data = data,
    x_var = x_var,
    y_var = y_var,
    chart_type = ct_normalized,
    n_var = n_var,
    cl_var = cl_var,
    freeze_var = freeze_var,
    part_var = part_var,
    notes_column = notes_column,
    multiply = multiply,
    options = list(...)
  )
}
