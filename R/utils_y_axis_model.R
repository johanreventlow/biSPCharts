# utils_y_axis_model.R
# Y-akse datamodel: UI-typer → interne klasser → kortvalg

# Interne klasser (konstanter)
INTERNAL_CLASSES <- list(
  MEASUREMENT = "MEASUREMENT",
  COUNT = "COUNT",
  PROPORTION = "PROPORTION",
  RATE_INTERNAL = "RATE_INTERNAL",
  TIME_BETWEEN = "TIME_BETWEEN",
  COUNT_BETWEEN = "COUNT_BETWEEN"
)

#' Afgør om en y-akse UI-type tilhører tids-familien
#'
#' Omfatter legacy `"time"` og de nye enheds-varianter fra Fase 2.
#' Bruges af `determine_internal_class()` og `default_time_unit_for_chart()`.
#'
#' @param ui_type Character vektor eller NULL.
#' @return Logical vektor samme længde som ui_type. FALSE for NA/tom.
#' @keywords internal
is_time_unit <- function(ui_type) {
  if (is.null(ui_type) || length(ui_type) == 0L) {
    return(logical(0))
  }
  ui <- tolower(as.character(ui_type))
  !is.na(ui) & ui %in% c("time", "time_minutes", "time_hours", "time_days")
}

#' Afgør intern klasse ud fra UI-type og data
#'
#' @param ui_type En af {"count" (TAL), "percent" (PROCENT), "rate" (RATE), "time" (TID)}
#' @param y Numeric vector (kan være heltal eller decimaltal)
#' @param n_present Logical – om N-kolonne er valgt (bruges som n/exposure)
#' @return Character – intern klasse
#' @keywords internal
#' @noRd
determine_internal_class <- function(ui_type, y, n_present = FALSE) {
  ui <- tolower(ui_type %||% "count")

  if (ui == "percent") {
    return(INTERNAL_CLASSES$PROPORTION)
  }

  if (ui == "rate") {
    return(INTERNAL_CLASSES$RATE_INTERNAL)
  }

  if (is_time_unit(ui)) {
    return(INTERNAL_CLASSES$TIME_BETWEEN)
  }

  # TAL (default = count/value)
  # COUNT hvis heltal ≥ 0 og ingen n/exposure; ellers MEASUREMENT
  y_num <- suppressWarnings(as.numeric(y))
  all_int <- all(!is.na(y_num)) && all(floor(y_num) == y_num) && all(y_num >= 0)
  if (all_int && !isTRUE(n_present)) {
    return(INTERNAL_CLASSES$COUNT)
  }
  return(INTERNAL_CLASSES$MEASUREMENT)
}

#' Foreslå korttype ud fra intern klasse
#'
#' @param internal_class Intern klasse fra determine_internal_class
#' @param n_present Logical – om N-kolonne er valgt (for P/U)
#' @param n_points Antal datapunkter (run chart fallback for små serier)
#' @return qicharts2-kode for korttype ("i", "c", "p", "u", "t", "g", "run")
#' @keywords internal
suggest_chart_type <- function(internal_class, n_present = FALSE, n_points = NA_integer_) {
  if (!is.na(n_points) && n_points < 12) {
    return("run")
  }

  ic <- toupper(internal_class %||% "MEASUREMENT")
  if (ic == INTERNAL_CLASSES$MEASUREMENT) {
    return("i")
  }
  if (ic == INTERNAL_CLASSES$COUNT) {
    return("c")
  }
  if (ic == INTERNAL_CLASSES$PROPORTION) {
    return("p")
  }
  if (ic == INTERNAL_CLASSES$RATE_INTERNAL) {
    return("u")
  }
  if (ic == INTERNAL_CLASSES$TIME_BETWEEN) {
    return("t")
  }
  if (ic == INTERNAL_CLASSES$COUNT_BETWEEN) {
    return("g")
  }
  return("run")
}

#' Vælg default Y-akse UI-type ud fra kontekst
#'
#' Særligt for run chart ønsker vi:
#' - Hvis både tæller og nævner er valgt: default = percent
#' - Hvis kun tæller: default = count
#' Brugeren kan altid overskrive.
#'
#' @param chart_type qicharts2-kode for korttype (fx "run")
#' @param n_present Logical – om N-kolonne er valgt
#' @return "percent" eller "count"
#' @keywords internal
decide_default_y_axis_ui_type <- function(chart_type, n_present) {
  ct <- get_qic_chart_type(chart_type)
  if (identical(ct, "run") && isTRUE(n_present)) {
    return("percent")
  }
  return("count")
}

#' Map diagramtype til Y-akse UI-type
#'
#' @param chart_type qicharts2-kode eller dansk label
#' @return one of {"count","percent","rate","time"}
#' @keywords internal
#' @noRd
chart_type_to_ui_type <- function(chart_type) {
  # "t", "pp" og "up" er kendte qic-koder, men ikke i CHART_TYPES_EN endnu,
  # så vi matcher dem direkte før kaldet til get_qic_chart_type() (som
  # ville falde tilbage til "run" og give forkert UI-type).
  if (identical(chart_type, "t")) {
    return("time_days")
  }
  if (identical(chart_type, "pp")) {
    return("percent")
  }
  if (identical(chart_type, "up")) {
    return("rate")
  }
  ct <- get_qic_chart_type(chart_type)
  if (ct %in% c("p", "pp")) {
    return("percent")
  }
  if (ct %in% c("u", "up")) {
    return("rate")
  }
  if (ct == "t") {
    return("time_days")
  }
  # i, mr, c, g og fallback
  return("count")
}

#' Foreslå default tids-enhed for en korttype
#'
#' Bruges af UI-laget til at pre-vælge en passende tids-enhed når
#' brugeren skifter korttype. Returnerer NULL for korttyper der ikke
#' typisk bruger tid på y-aksen — caller falder så tilbage til eget default.
#'
#' @param chart_type character. qicharts2-kode eller dansk label.
#' @return character eller NULL.
#' @keywords internal
default_time_unit_for_chart <- function(chart_type) {
  if (is.null(chart_type) || length(chart_type) == 0L) {
    return(NULL)
  }
  if (is.na(chart_type)) {
    return(NULL)
  }
  # "t" er endnu ikke i CHART_TYPES_EN; matcher direkte før get_qic_chart_type().
  if (identical(chart_type, "t")) {
    return("time_days")
  }
  ct <- get_qic_chart_type(chart_type)
  if (identical(ct, "t")) {
    return("time_days")
  }
  NULL
}
