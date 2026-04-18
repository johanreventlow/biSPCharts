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
  1, 2, 5, 10, 15, 20, 30, # minutter
  60, 120, 180, 240, 360, 720, # timer (1t, 2t, 3t, 4t, 6t, 12t)
  1440, 2880, 10080, 43200 # dage (1d, 2d, 7d, 30d)
)

#' Tilladte kandidat-intervaller pr. input-enhed
#'
#' Filtrerer TIME_BREAK_CANDIDATES baseret paa hvilke der er "naturlige"
#' i den valgte input-enhed. Fx time_hours tillader ikke 15m-intervaller
#' (= 0.25 t) men tillader 30m (= 0.5 t). time_days kraever mindst 12t
#' interval for at undgaa forvirrende sub-dag ticks.
#'
#' @keywords internal
TIME_BREAK_CANDIDATES_BY_UNIT <- list(
  time_minutes = TIME_BREAK_CANDIDATES,
  time_hours   = c(30, 60, 120, 240, 360, 720, 1440, 2880, 10080, 43200),
  time_days    = c(720, 1440, 2880, 10080, 43200)
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
#' \dontrun{
#' format_time_composite(90) # "1t 30m"
#' format_time_composite(51) # "51m"
#' format_time_composite(3660) # "2d 13t"
#' format_time_composite(-30) # "-30m"
#' }
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
#' @param input_unit character eller NULL. En af 'time_minutes',
#'   'time_hours', 'time_days'. Begraenser hvilke kandidat-intervaller
#'   der overvejes (fx time_days bruger kun >= 12t intervaller).
#'   Default NULL = alle kandidater (bagudkompatibel).
#' @return numeric vektor. Tick-positioner i minutter.
#' @keywords internal
#' @examples
#' \dontrun{
#' time_breaks(c(0, 120)) # 0 30 60 90 120
#' time_breaks(c(15, 185)) # 0 30 60 90 120 150 180
#' time_breaks(c(0, 480)) # 0 120 240 360 480
#' }
time_breaks <- function(y_values, target_n = 5L, input_unit = NULL) {
  # Defensiv: filtrer ikke-finite (NA, NaN, Inf, -Inf) og tomme inputs.
  # ggplot2 passerer undertiden Inf/-Inf under layout; seq() ville senere
  # crashe med 'to' must be a finite number uden denne filtrering.
  y_clean <- y_values[is.finite(y_values)]
  if (length(y_clean) == 0L) {
    return(numeric(0))
  }

  y_min <- min(y_clean)
  y_max <- max(y_clean)

  # Konstant range: returnér enkelt tick paa vaerdien
  if (y_min == y_max) {
    return(y_min)
  }

  # Vaelg kandidat-liste baseret paa input_unit
  candidates <- if (!is.null(input_unit) &&
    input_unit %in% names(TIME_BREAK_CANDIDATES_BY_UNIT)) {
    TIME_BREAK_CANDIDATES_BY_UNIT[[input_unit]]
  } else {
    TIME_BREAK_CANDIDATES
  }

  # Primaer: stoerste interval med >= target_n ticks.
  # Itererer alle kandidater (floor-snap kan give non-monotonisk n_ticks
  # i sjaeldne tilfaelde for smaa target_n — omkostningen er ubetydelig).
  chosen_interval <- pick_break_interval(y_min, y_max, candidates, min_ticks = target_n)

  # Fallback 1: prøv ufiltreret liste hvis filtreret ikke gav resultat
  if (is.null(chosen_interval) && !identical(candidates, TIME_BREAK_CANDIDATES)) {
    chosen_interval <- pick_break_interval(
      y_min, y_max, TIME_BREAK_CANDIDATES,
      min_ticks = target_n
    )
  }

  # Fallback 2: meget smal range — brug mindste interval med >= 2 ticks
  if (is.null(chosen_interval)) {
    chosen_interval <- pick_break_interval(
      y_min, y_max, TIME_BREAK_CANDIDATES,
      min_ticks = 2L, pick_first = TRUE
    )
  }

  # Fallback 3: sub-unit range (f.eks. 0.3-0.9 min) — returnér
  # data-bracketing tick-par saa aksen ikke bliver blank.
  if (is.null(chosen_interval)) {
    return(c(y_min, y_max))
  }

  start <- floor(y_min / chosen_interval) * chosen_interval
  end <- floor(y_max / chosen_interval) * chosen_interval

  seq(start, end, by = chosen_interval)
}

#' Vælg tick-interval fra en kandidat-liste
#'
#' @param y_min,y_max numeric. Range-grænser.
#' @param candidates numeric. Kandidat-intervaller (stigende sorteret).
#' @param min_ticks integer. Mindstekrav til antal ticks i det valgte interval.
#' @param pick_first logical. TRUE = returnér første match; FALSE = returnér
#'   største interval der stadig opfylder min_ticks-kravet (default).
#' @return numeric eller NULL hvis intet interval passer.
#' @keywords internal
pick_break_interval <- function(y_min, y_max, candidates,
                                min_ticks = 5L, pick_first = FALSE) {
  chosen <- NULL
  for (interval in candidates) {
    start <- floor(y_min / interval) * interval
    end <- floor(y_max / interval) * interval
    n_ticks <- (end - start) / interval + 1L
    if (n_ticks >= min_ticks) {
      chosen <- interval
      if (pick_first) {
        break
      }
    }
  }
  chosen
}
