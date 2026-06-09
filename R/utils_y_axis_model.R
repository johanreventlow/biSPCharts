# utils_y_axis_model.R
# Y-akse datamodel: UI-typer → interne klasser → kortvalg
#
# NB: INTERNAL_CLASSES er flyttet til R/config_y_axis_classes.R (#461) for
# at følge konfig-arkitekturen (constants i config_*.R + getter). Læs den
# fil hvis du vil tilføje/ændre interne klasser.

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
  # Run-chart fallback ved kort serie. Bevidst 12L her (samme vaerdi som
  # get_spc_warning_threshold() men konceptuelt separat: dette er en
  # chart-type-beslutning, ikke en advarselsgransens).
  # Koblede de to ville give stiltiende adfaerdsaendring ved fremtidig
  # justering af warning-tærsklen. (#417 — se PR-beskrivelse)
  if (!is.na(n_points) && n_points < 12L) {
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

#' Afgør om en proportions-centerline overstiger 100%
#'
#' For I'- og run-kort med naevner plottes per-punkt-andelen y/n. Centerlinjen
#' er den pooled andel `sum(tæller)/sum(nævner)` (samme som pbcharts beregner
#' via `weighted.mean(y, den)` i `pbc.i`). Naar denne overstiger 1.0 (100%) er
#' serien ikke en andel men en rate (haendelser pr. enhed, kan overstige 1),
#' og "procent" giver et misvisende default.
#'
#' @param y Numeric/character vektor – tæller-kolonne (parses defensivt).
#' @param n Numeric/character vektor – nævner-kolonne.
#' @return Logical(1). TRUE hvis pooled centerline > 1. FALSE ved manglende
#'   data, nul/negativ samlet nævner eller NULL-input (saa default forbliver
#'   procent — konservativt).
#' @keywords internal
#' @noRd
proportion_centerline_exceeds_unity <- function(y, n) {
  if (is.null(y) || is.null(n) || length(y) == 0L || length(n) == 0L) {
    return(FALSE)
  }
  y_num <- suppressWarnings(as.numeric(y))
  n_num <- suppressWarnings(as.numeric(n))
  ok <- !is.na(y_num) & !is.na(n_num) & n_num > 0
  if (!any(ok)) {
    return(FALSE)
  }
  den_sum <- sum(n_num[ok])
  if (!is.finite(den_sum) || den_sum <= 0) {
    return(FALSE)
  }
  cl <- sum(y_num[ok]) / den_sum
  is.finite(cl) && cl > 1
}

#' Vælg default Y-akse UI-type ud fra kontekst
#'
#' Særligt for run chart ønsker vi:
#' - Hvis både tæller og nævner er valgt: default = percent
#' - Hvis kun tæller: default = count
#' Brugeren kan altid overskrive.
#'
#' For I'- og run-kort med nævner gælder desuden: hvis den pooled centerline
#' (`sum(tæller)/sum(nævner)`) overstiger 100%, er serien reelt en rate, ikke
#' en andel → default = rate i stedet for percent. Kræver at `y` og `n` gives;
#' uden dem bevares den hidtidige procent-default (bagudkompatibelt).
#'
#' @param chart_type qicharts2-kode for korttype (fx "run")
#' @param n_present Logical – om N-kolonne er valgt
#' @param y Numeric/character vektor – tæller-kolonne (valgfri). Bruges kun til
#'   centerline-tjek for run/i'-kort med nævner.
#' @param n Numeric/character vektor – nævner-kolonne (valgfri).
#' @return "percent", "rate" eller "count"
#' @keywords internal
decide_default_y_axis_ui_type <- function(chart_type, n_present, y = NULL, n = NULL) {
  ct <- get_qic_chart_type(chart_type)
  # Run og I-prime: med naevner plottes en andel (y/n) -> default procent.
  # Uden naevner -> tal. Brugeren kan altid overskrive.
  if (ct %in% c("run", "i'") && isTRUE(n_present)) {
    # Andel > 100% i centerlinjen => det er en rate, ikke en procent.
    if (proportion_centerline_exceeds_unity(y, n)) {
      return("rate")
    }
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
