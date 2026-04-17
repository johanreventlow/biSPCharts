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

# TICK-BREAKS =================================================================

#' Generér tids-naturlige tick-breaks
#'
#' Vaelger det STOERSTE interval fra TIME_BREAK_CANDIDATES der stadig giver
#' mindst `target_n` ticks inden for data-range. Kriteriet resulterer i
#' naturligt grovere ticks for store ranges og finere for smalle ranges.
#' Begge ender snappes med floor() til multipla af det valgte interval
#' (ggplot2 udvider selv aksen med expansion(), saa y_max er stadig synligt).
#'
#' @param y_values numeric. Data-range at generere ticks til.
#' @param target_n integer. Minimums-antal ticks. Default 5L.
#' @return numeric vektor. Tick-positioner i minutter.
#' @keywords internal
#' @examples
#' time_breaks(c(0, 120))    # 0 30 60 90 120
#' time_breaks(c(15, 185))   # 0 30 60 90 120 150 180
#' time_breaks(c(0, 480))    # 0 120 240 360 480
time_breaks <- function(y_values, target_n = 5L) {
  # Defensiv: filtrer NA og tomme inputs
  y_clean <- y_values[!is.na(y_values)]
  if (length(y_clean) == 0L) {
    return(numeric(0))
  }

  y_min <- min(y_clean)
  y_max <- max(y_clean)

  # Konstant range: returnér enkelt tick paa vaerdien
  if (y_min == y_max) {
    return(y_min)
  }

  # Primaer: stoerste interval med >= target_n ticks.
  # Intervallerne itereres fra lille til stor; n_ticks falder monotont, saa
  # vi kan break ud af loekken saa snart n_ticks falder under target_n.
  chosen_interval <- NULL
  for (interval in TIME_BREAK_CANDIDATES) {
    start <- floor(y_min / interval) * interval
    end <- floor(y_max / interval) * interval
    n_ticks <- (end - start) / interval + 1L
    if (n_ticks >= target_n) {
      chosen_interval <- interval
    } else if (!is.null(chosen_interval)) {
      # Vi har et valg; videre intervaller vil kun give faerre ticks
      break
    }
  }

  # Fallback 1: meget smal range — brug mindste interval med >= 2 ticks
  if (is.null(chosen_interval)) {
    for (interval in TIME_BREAK_CANDIDATES) {
      start <- floor(y_min / interval) * interval
      end <- floor(y_max / interval) * interval
      n_ticks <- (end - start) / interval + 1L
      if (n_ticks >= 2L) {
        chosen_interval <- interval
        break
      }
    }
  }

  # Fallback 2: patologisk case — brug mindste kandidat
  if (is.null(chosen_interval)) {
    chosen_interval <- TIME_BREAK_CANDIDATES[[1]]
  }

  start <- floor(y_min / chosen_interval) * chosen_interval
  end <- floor(y_max / chosen_interval) * chosen_interval

  seq(start, end, by = chosen_interval)
}
