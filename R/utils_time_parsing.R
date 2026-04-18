# utils_time_parsing.R
# Parsing af tids-input til kanoniske minutter.
#
# Understøtter:
# - Numeric + input_unit ('time_minutes', 'time_hours', 'time_days')
# - hms::hms / difftime objekter (tilføjes i Task 2a.4)
# - Karakter-strenge i HH:MM og HH:MM:SS format (tilføjes i Task 2a.5)
# - NA og ugyldige værdier håndteres graciously
#
# Kanonisk output: minutter som double.
# Se docs/superpowers/specs/2026-04-17-time-yaxis-design.md.

# ENHEDSKONSTANTER ============================================================

#' Skaleringsfaktor fra input-enhed til kanoniske minutter
#' @keywords internal
TIME_INPUT_UNIT_SCALES <- c(
  time_minutes = 1,
  time_hours   = 60,
  time_days    = 1440
)

# PARSING HOVEDFUNKTION =======================================================

#' Konvertér tids-input til kanoniske minutter
#'
#' @param x Input-vektor. Kan være numeric, character (HH:MM[:SS]),
#'   hms/difftime objekt, eller NA.
#' @param input_unit Character. En af 'time_minutes', 'time_hours', 'time_days'.
#'   Ignoreres hvis x er hms/difftime eller HH:MM-streng. Default: 'time_minutes'.
#' @return Numeric vektor. Minutter som double. NA for ugyldig input.
#' @keywords internal
parse_time_to_minutes <- function(x, input_unit = "time_minutes") {
  if (length(x) == 0L) {
    return(numeric(0))
  }

  # Validér input_unit; fall-back til minutter med advarsel
  if (is.null(input_unit) || !input_unit %in% names(TIME_INPUT_UNIT_SCALES)) {
    warning(
      "parse_time_to_minutes: ukendt input_unit '",
      input_unit %||% "NULL",
      "' — antager time_minutes"
    )
    input_unit <- "time_minutes"
  }

  scale <- TIME_INPUT_UNIT_SCALES[[input_unit]]

  # hms: altid sekunder → divider med 60
  # (hms ignorerer units-arg og returnerer altid sekunder via as.numeric)
  if (inherits(x, "hms")) {
    return(as.numeric(x) / 60)
  }

  # difftime: konvertér direkte til minutter via units-arg
  if (inherits(x, "difftime")) {
    return(as.numeric(x, units = "mins"))
  }

  # Numeric path
  if (is.numeric(x)) {
    return(x * scale)
  }

  # Fremtidige paths (hms/difftime/character) tilføjes i senere tasks
  suppressWarnings({
    coerced <- as.numeric(as.character(x))
  })
  if (all(is.na(coerced)) && !all(is.na(x))) {
    warning(
      "parse_time_to_minutes: kunne ikke parse input af type '",
      paste(class(x), collapse = "/"),
      "' — returnerer NA. HH:MM og hms-support kommer i senere task."
    )
  }
  coerced * scale
}
