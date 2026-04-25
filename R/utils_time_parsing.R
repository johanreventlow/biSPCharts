# utils_time_parsing.R
# Parsing af tids-input til kanoniske minutter.
#
# Understoetter:
# - Numeric + input_unit ('time_minutes', 'time_hours', 'time_days')
# - hms::hms / difftime objekter (tilfoejes i Task 2a.4)
# - Karakter-strenge i HH:MM og HH:MM:SS format (tilfoejes i Task 2a.5)
# - NA og ugyldige vaerdier haandteres graciously
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

#' Konverter tids-input til kanoniske minutter
#'
#' @param x Input-vektor. Kan vaere numeric, character (HH:MM[:SS]),
#'   hms/difftime objekt, eller NA.
#' @param input_unit Character. En af 'time_minutes', 'time_hours', 'time_days'.
#'   Ignoreres hvis x er hms/difftime eller HH:MM-streng. Default: 'time_minutes'.
#' @return Numeric vektor. Minutter som double. NA for ugyldig input.
#' @keywords internal
#' @noRd
parse_time_to_minutes <- function(x, input_unit = "time_minutes") {
  if (length(x) == 0L) {
    return(numeric(0))
  }

  # Valider input_unit; fall-back til minutter med advarsel
  if (is.null(input_unit) || !input_unit %in% names(TIME_INPUT_UNIT_SCALES)) {
    warning(
      "parse_time_to_minutes: ukendt input_unit '",
      input_unit %||% "NULL",
      "' \u2014 antager time_minutes"
    )
    input_unit <- "time_minutes"
  }

  scale <- TIME_INPUT_UNIT_SCALES[[input_unit]]

  # hms: altid sekunder -> divider med 60
  # (hms ignorerer units-arg og returnerer altid sekunder via as.numeric)
  if (inherits(x, "hms")) {
    return(as.numeric(x) / 60)
  }

  # difftime: konverter direkte til minutter via units-arg
  if (inherits(x, "difftime")) {
    return(as.numeric(x, units = "mins"))
  }

  # Numeric path
  if (is.numeric(x)) {
    return(x * scale)
  }

  # Character/factor-input: proev HH:MM[:SS] parse foerst, fald tilbage til numeric
  if (is.character(x) || is.factor(x)) {
    x_char <- as.character(x)
    hhmm_result <- parse_hhmm_strings(x_char)

    # For vaerdier hvor HH:MM-parse fejler (NA), proev numeric-parse
    numeric_fallback <- suppressWarnings(as.numeric(x_char)) * scale
    result <- ifelse(is.na(hhmm_result), numeric_fallback, hhmm_result)
    return(result)
  }

  # Ukendt type -- returner NA med warning
  suppressWarnings({
    coerced <- as.numeric(as.character(x))
  })
  if (all(is.na(coerced)) && !all(is.na(x))) {
    warning(
      "parse_time_to_minutes: kunne ikke parse input af type '",
      paste(class(x), collapse = "/"),
      "' \u2014 returnerer NA."
    )
  }
  coerced * scale
}

#' Parse HH:MM eller HH:MM:SS strenge til minutter
#'
#' Sekunder konverteres til broekdele af minutter (rundes ikke her --
#' det haandteres af format_time_composite() ved render-tid).
#' Ugyldige strenge returnerer NA.
#'
#' @param x Character vektor.
#' @return Numeric vektor med minutter.
#' @keywords internal
parse_hhmm_strings <- function(x) {
  # Regex: optional negative sign, timer (1-3 cifre), minutter (1-2 cifre),
  # valgfrit :SS hvor SS er 1-2 cifre.
  pattern <- "^(-?)(\\d{1,3}):(\\d{1,2})(?::(\\d{1,2}))?$"

  matches <- stringr::str_match(x, pattern)
  # matches er en matrix med kolonner: [full, sign, hours, mins, secs]
  n <- nrow(matches)
  result <- vapply(seq_len(n), function(i) {
    if (is.na(matches[i, 1])) {
      return(NA_real_)
    }
    sign <- if (identical(matches[i, 2], "-")) -1 else 1
    hours <- suppressWarnings(as.numeric(matches[i, 3]))
    mins <- suppressWarnings(as.numeric(matches[i, 4]))
    secs_str <- matches[i, 5]
    secs <- if (is.na(secs_str)) 0 else suppressWarnings(as.numeric(secs_str))
    if (any(is.na(c(hours, mins, secs)))) {
      return(NA_real_)
    }
    sign * (hours * 60 + mins + secs / 60)
  }, numeric(1))
  result
}
