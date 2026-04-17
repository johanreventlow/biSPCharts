# utils_time_formatting.R
# Tidshaandtering paa y-aksen: komposit-format og tids-naturlige tick-breaks
#
# Ansvar:
# - format_time_composite(): formatér minutter som "1t 30m", "45m", "2d 4t"
# - time_breaks(): generér tick-breaks paa tids-naturlige intervaller
# - TIME_BREAK_CANDIDATES: kandidat-intervaller i minutter
#
# Kanonisk intern enhed: minutter (double).
# Se docs/superpowers/specs/2026-04-17-time-yaxis-design.md for rationale.

# KANDIDAT-INTERVALLER ========================================================

#' Tids-naturlige kandidat-intervaller i minutter
#'
#' Bruges af time_breaks() til at vaelge tick-afstand. Daekker fra 1 minut
#' op til 30 dage.
#'
#' @keywords internal
TIME_BREAK_CANDIDATES <- c(
  1, 2, 5, 10, 15, 20, 30,       # minutter
  60, 120, 180, 240, 360, 720,   # timer (1t, 2t, 3t, 4t, 6t, 12t)
  1440, 2880, 10080, 43200       # dage (1d, 2d, 7d, 30d)
)

# KOMPOSIT FORMATERING ========================================================

#' Formatér minutter som komposit tidsstreng
#'
#' Runder input til hele minutter foer komponentopdeling for at undgaa
#' overflow (59,7 min -> `1t`, ikke `60m`). Max 2 komponenter for laesbarhed:
#' ved dage+timer vises ikke minutter.
#'
#' @param minutes numeric. Tidsvaerdi i minutter. Kan vaere negativ.
#' @return character. Komposit-formateret streng. NA_character_ hvis input er NA.
#' @keywords internal
#' @examples
#' format_time_composite(90)    # "1t 30m"
#' format_time_composite(51)    # "51m"
#' format_time_composite(3660)  # "2d 13t"
#' format_time_composite(-30)   # "-30m"
format_time_composite <- function(minutes) {
  if (length(minutes) == 0) {
    return(character(0))
  }

  vapply(minutes, format_time_composite_single, character(1))
}

#' @keywords internal
format_time_composite_single <- function(v) {
  if (is.na(v)) {
    return(NA_character_)
  }

  sign_prefix <- if (v < 0) "-" else ""
  v_int <- as.integer(round(abs(v)))

  d <- v_int %/% 1440L
  rem <- v_int %% 1440L
  t <- rem %/% 60L
  m <- rem %% 60L

  result <- if (d > 0L && t > 0L) {
    paste0(d, "d ", t, "t")
  } else if (d > 0L) {
    paste0(d, "d")
  } else if (t > 0L && m > 0L) {
    paste0(t, "t ", m, "m")
  } else if (t > 0L) {
    paste0(t, "t")
  } else if (m > 0L) {
    paste0(m, "m")
  } else {
    "0m"
  }

  paste0(sign_prefix, result)
}
