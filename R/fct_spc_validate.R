# fct_spc_validate.R
# Validerings-helper for SPC pipeline.

#' Valider SPC-anmodning og returner et spc_request-objekt
#'
#' Tjekker alle obligatoriske parametre og data-egenskaber, og returnerer
#' et `spc_request` S3-objekt hvis input er gyldigt. Kaster `spc_input_error`
#' ved ugyldig input -- fejl propagerer direkte til caller.
#'
#' @param data data.frame med SPC-data.
#' @param x_var character. Kolonne-navn for x-aksen.
#' @param y_var character. Kolonne-navn for maale-kolonnen.
#' @param chart_type character. SPC chart-type (fx "run", "p", "u").
#' @param n_var character eller NULL. Kolonne-navn for naevner.
#' @param cl_var character eller NULL. Manuel centerlinje-kolonne.
#' @param freeze_var character eller NULL. Freeze-graense-kolonne.
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
  # 1. data er paakraevet og skal vaere data.frame
  if (is.null(data)) {
    spc_abort(
      "data parameter er p\u00e5kr\u00e6vet (data required): m\u00e5 ikke v\u00e6re NULL",
      class = "spc_input_error"
    )
  }
  if (!is.data.frame(data)) {
    spc_abort("data skal v\u00e6re en data.frame", class = "spc_input_error")
  }

  # 2. x_var er paakraevet
  if (is.null(x_var) || !nzchar(trimws(x_var))) {
    spc_abort(
      "x_var parameter er p\u00e5kr\u00e6vet (x_var required): angiv kolonnenavn for x-aksen",
      class = "spc_input_error"
    )
  }

  # 3. y_var er paakraevet
  if (is.null(y_var) || !nzchar(trimws(y_var))) {
    spc_abort(
      "y_var parameter er p\u00e5kr\u00e6vet (y_var required): angiv kolonnenavn for m\u00e5lekolonnen",
      class = "spc_input_error"
    )
  }

  # 4. chart_type er paakraevet og skal normaliseres
  if (is.null(chart_type) || !nzchar(trimws(chart_type))) {
    spc_abort(
      "chart_type parameter er p\u00e5kr\u00e6vet (chart_type required)",
      class = "spc_input_error"
    )
  }
  ct_normalized <- tolower(trimws(chart_type))

  # 5. chart_type skal vaere en understoettet type
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

  # 6. n_var er paakraevet for P-, U-kort (og pp, up)
  if (ct_normalized %in% c("p", "pp", "u", "up") && is.null(n_var)) {
    spc_abort(
      paste0(
        "n_var (denominator) required for ", ct_normalized, "-kort. ",
        "Angiv kolonnenavnet for n\u00e6vneren."
      ),
      class = "spc_input_error"
    )
  }

  # 7. data maa ikke vaere tom
  if (nrow(data) == 0) {
    spc_abort(
      "Ingen r\u00e6kker fundet i data (empty dataset). Upload data f\u00f8rst.",
      class = "spc_input_error"
    )
  }

  # 8. Mindst 3 datapunkter kraeves
  if (nrow(data) < 3) {
    spc_abort(
      paste0(
        "For f\u00e5 datapunkter: ", nrow(data), " r\u00e6kke(r) fundet (too few/insufficient). ",
        "minimum 3 datapunkter kr\u00e6ves for SPC-analyse."
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
      paste0("N\u00e6vner-kolonne '", n_var, "' blev ikke fundet i data (missing column: n_var)"),
      class = "spc_input_error"
    )
  }

  # 10. y_var maa ikke udelukkende bestaa af NA
  y_vals <- data[[y_var]]
  if (all(is.na(y_vals))) {
    spc_abort(
      paste0(
        "Kolonnen '", y_var, "' indeholder udelukkende NA-v\u00e6rdier. ",
        "Ingen komplette datapunkter til r\u00e5dighed (all NA/no valid values)."
      ),
      class = "spc_input_error"
    )
  }

  # 11. y_var skal vaere numerisk (eller konverterbar -- inkl. danske talformater)
  if (!is.numeric(y_vals)) {
    std_converted <- suppressWarnings(as.numeric(as.character(y_vals)))
    danish_converted <- suppressWarnings(as.numeric(gsub(",", ".", as.character(y_vals))))
    any_convertible <- !all(is.na(std_converted)) || !all(is.na(danish_converted))
    non_na_vals <- !all(is.na(y_vals))
    if (non_na_vals && !any_convertible) {
      spc_abort(
        paste0(
          "Kolonnen '", y_var, "' indeholder ikke-numeriske v\u00e6rdier og kan ikke konverteres (invalid/convert). ",
          "Kolonnen skal indeholde tal (ogs\u00e5 dansk talformat med komma accepteres)."
        ),
        class = "spc_input_error"
      )
    }
  }

  # 12. n_var maa ikke indeholde ugyldige vaerdier for rate-baserede kort (BFHcharts 0.9.0+)
  if (!is.null(n_var) && n_var %in% names(data) &&
    ct_normalized %in% c("p", "pp", "u", "up")) {
    n_vals <- data[[n_var]]
    n_numeric <- suppressWarnings(as.numeric(n_vals))
    if (all(is.na(n_numeric)) && is.character(n_vals)) {
      n_numeric <- suppressWarnings(as.numeric(gsub(",", ".", n_vals)))
    }
    # n=0 er gyldig klinisk observation ("ingen patienter denne m\u00e5ned") og
    # konverteres til NA i prepare-steget (ikke en fejl her). Kun n<0 er ugyldig.
    invalid_n <- !is.na(n_numeric) & (n_numeric < 0 | is.infinite(n_numeric))
    if (any(invalid_n)) {
      spc_abort(
        paste0(
          "N\u00e6vner-kolonnen '", n_var, "' indeholder ugyldige v\u00e6rdier (< 0 eller uendelig). ",
          "N\u00e6vner skal v\u00e6re ikke-negativ for ", toupper(ct_normalized), "-kort."
        ),
        class = "spc_input_error"
      )
    }
    # Alle n\u00e6vnere er 0: ingen brugbare data
    all_zero_n <- !is.na(n_numeric) & n_numeric == 0
    if (all(all_zero_n | is.na(n_numeric))) {
      spc_abort(
        "Alle n\u00e6vnerv\u00e6rdier er nul eller NA. Ingen brugbare data til SPC-analyse.",
        class = "spc_input_error"
      )
    }
  }

  # 13. cl_var understøttes ikke: BFHcharts' cl-parameter accepterer kun skalær (len=1),
  # ikke per-række centerline. Tavs ignorering er farligere end fejl -- klinikere
  # tror at appen respekterer cl_var-konfigurationen. Fail-fast til bruger ved sæt.
  if (!is.null(cl_var) && nzchar(trimws(cl_var))) {
    spc_abort(
      paste0(
        "cl_var-parameteret ('", cl_var, "') understøttes ikke i nuværende version. ",
        "BFHcharts understøtter kun skalær centerline (cl), ikke per-række værdier. ",
        "Brug 'part_var' til fase-opdeling med automatisk centerline per fase."
      ),
      class = "spc_input_error"
    )
  }

  # 15. P/P'-kort: tæller <= nævner (proportion kan ikke overstige 1)
  if (!is.null(n_var) && n_var %in% names(data) && ct_normalized %in% c("p", "pp")) {
    y_num <- suppressWarnings(as.numeric(data[[y_var]]))
    if (all(is.na(y_num)) && is.character(data[[y_var]])) {
      y_num <- suppressWarnings(as.numeric(gsub(",", ".", data[[y_var]])))
    }
    n_vals2 <- suppressWarnings(as.numeric(data[[n_var]]))
    if (all(is.na(n_vals2)) && is.character(data[[n_var]])) {
      n_vals2 <- suppressWarnings(as.numeric(gsub(",", ".", data[[n_var]])))
    }
    invalid_prop <- !is.na(y_num) & !is.na(n_vals2) & y_num > n_vals2
    if (any(invalid_prop)) {
      first_invalid <- which(invalid_prop)[1]
      spc_abort(
        paste0(
          "Tæller-kolonne '", y_var, "' overstiger nævner-kolonne '", n_var, "' ",
          "i række ", first_invalid, " (", y_num[first_invalid], " > ", n_vals2[first_invalid], "). ",
          "P-kort kræver at tæller ≤ nævner (proportioner kan ikke overskride 100%)."
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
