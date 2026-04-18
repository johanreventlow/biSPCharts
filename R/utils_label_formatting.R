# utils_label_formatting.R
# Delt formatering af y-akse værdier for konsistens mellem labels og akser
#
# Sikrer at labels formateres PRÆCIS som y-aksen for alle enhedstyper

#' Formatér y-akse værdi til display string
#'
#' Formaterer numeriske værdier til display strings der matcher y-akse formatting.
#' Understøtter flere enhedstyper: count, percent, rate, time.
#'
#' @param val numeric værdi at formatere
#' @param y_unit character enhedstype ("count", "percent", "rate", "time", eller andet)
#' @param y_range numeric(2) legacy-parameter, ikke laengere brugt. Bevaret
#'   for bagudkompatibilitet — tidligere brugt til kontekst-baseret enhedsvalg
#'   for "time"-enheden.
#' @return character formateret string
#'
#' @details
#' Formatering per enhedstype:
#' - **count**: K/M/mia notation for store tal, dansk decimal/tusind separator
#' - **percent**: scales::label_percent() formatering
#' - **rate**: dansk decimal notation, decimaler kun hvis nødvendigt
#' - **time**: komposit-format via format_time_composite() (0m, 30m, 1t, 1t 30m, 1d, 2d 13t)
#' - **default**: dansk decimal notation
#'
#' @examples
#' \dontrun{
#' format_y_value(1234, "count")
#' # Returns: "1K"
#'
#' format_y_value(0.456, "percent")
#' # Returns: "46%"
#'
#' format_y_value(90, "time")
#' # Returns: "1t 30m"
#' }
#'
#' @keywords internal
format_y_value <- function(val, y_unit, y_range = NULL) {
  # Input validation
  if (is.na(val)) {
    return(NA_character_)
  }

  if (!is.numeric(val)) {
    warning("format_y_value: val skal være numerisk, modtog: ", class(val))
    return(as.character(val))
  }

  # Percent formatting
  if (y_unit == "percent") {
    # Matcher scale_y_continuous(labels = scales::label_percent())
    return(scales::label_percent()(val))
  }

  # Count formatting med K/M/mia notation
  if (y_unit == "count") {
    if (abs(val) >= 1e9) {
      scaled <- val / 1e9
      if (scaled == round(scaled)) {
        return(paste0(round(scaled), " mia."))
      } else {
        return(paste0(format(scaled, decimal.mark = ",", nsmall = 1), " mia."))
      }
    } else if (abs(val) >= 1e6) {
      scaled <- val / 1e6
      if (scaled == round(scaled)) {
        return(paste0(round(scaled), "M"))
      } else {
        return(paste0(format(scaled, decimal.mark = ",", nsmall = 1), "M"))
      }
    } else if (abs(val) >= 1e3) {
      scaled <- val / 1e3
      if (scaled == round(scaled)) {
        return(paste0(round(scaled), "K"))
      } else {
        return(paste0(format(scaled, decimal.mark = ",", nsmall = 1), "K"))
      }
    } else {
      # For values < 1000: show decimals only if present
      if (val == round(val)) {
        return(format(round(val), decimal.mark = ",", big.mark = "."))
      } else {
        return(format(val, decimal.mark = ",", big.mark = ".", nsmall = 1))
      }
    }
  }

  # Rate formatting - kun decimaler hvis tilstede
  if (y_unit == "rate") {
    if (val == round(val)) {
      return(format(round(val), decimal.mark = ","))
    } else {
      return(format(val, decimal.mark = ",", nsmall = 1))
    }
  }

  # Time formatting (input: kanoniske minutter) - komposit-format
  # Dækker legacy "time" og nye time_minutes/time_hours/time_days.
  # Bruger format_time_composite() for konsistens med format_y_axis_time().
  # y_range-parameteren er ikke laengere relevant — komposit-format haandterer
  # minutter/timer/dage automatisk (0m, 30m, 1t, 1t 30m, 1d, 2d 13t).
  if (is_time_unit(y_unit)) {
    return(format_time_composite(val))
  }

  # Default formatting - dansk notation
  if (val == round(val)) {
    return(format(round(val), decimal.mark = ","))
  } else {
    return(format(val, decimal.mark = ",", nsmall = 1))
  }
}
