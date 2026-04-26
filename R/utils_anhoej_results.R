# utils_anhoej_results.R
# Hjaelpefunktioner til opdatering af Anhoej resultater (serielaengde og kryds)

#' Filtrer qic_data til seneste part hvis skift er aktivt
#'
#' Naar brugeren har aktiveret "Skift" (parts/phases), skal beregninger
#' kun baseres paa den seneste part, ikke hele datasaettet.
#'
#' @param qic_data data.frame. QIC data med part kolonne
#' @param show_phases logical. TRUE hvis parts/skift er aktivt
#' @return data.frame. Filtreret til seneste part eller hele datasaet
#' @keywords internal
filter_latest_part <- function(qic_data, show_phases = FALSE) {
  # Hvis ingen parts eller show_phases er FALSE, returner hele datasaettet
  if (!isTRUE(show_phases) || is.null(qic_data) || !"part" %in% names(qic_data)) {
    return(qic_data)
  }

  # Find seneste part
  latest_part <- max(qic_data$part, na.rm = TRUE)

  # Returner kun data fra seneste part
  qic_data[qic_data$part == latest_part & !is.na(qic_data$part), ]
}

#' Opdater Anhoej resultater ud fra nye QIC-beregninger
#'
#' Regler:
#' - Hvis nye beregninger indeholder gyldige metrics (longest_run eller n_crossings),
#'   saa opdateres resultaterne altid og markeres som gyldige
#' - Hvis metrics er NA og centerline (baseline) er aendret, opdateres til NA-resultater
#'   (vi bevarer ikke gamle vaerdier -- UI skal afspejle den nye tilstand)
#' - Hvis metrics er NA og centerline ikke er aendret, og der fandtes gyldige vaerdier foer,
#'   bevares de gamle vaerdier (for at undgaa midlertidig flimmer under beregning)
#'
#' Fase-filtrering og Anhoej-udledning haandteres af `derive_anhoej_results()`
#' foer dette kald. Denne funktion bevaarer udelukkende preserve-politikken.
#'
#' @param previous list. Forrige `anhoej_results` (kan vaere NULL ved foerste koersel)
#' @param qic_results list. Nye beregnede metrics (fra `derive_anhoej_results()`)
#' @param centerline_changed logical. TRUE hvis centerline/baseline er aendret (inkl. ryddet)
#' @return list. Opdateret `anhoej_results`
#' @keywords internal
update_anhoej_results <- function(previous, qic_results, centerline_changed = FALSE) {
  # Defensive input checks
  if (is.null(qic_results) || !is.list(qic_results)) {
    return(previous)
  }

  has_metrics <- (!is.null(qic_results$longest_run) && !is.na(qic_results$longest_run)) ||
    (!is.null(qic_results$n_crossings) && !is.na(qic_results$n_crossings))

  # 1) Gyldige metrics -> altid opdater
  if (isTRUE(has_metrics)) {
    qic_results$has_valid_data <- TRUE
    return(qic_results)
  }

  # 2) Ingen metrics og centerline aendret -> opdater til NA-resultater (ikke bevar gamle)
  if (isTRUE(centerline_changed)) {
    qic_results$has_valid_data <- FALSE
    if (is.null(qic_results$message)) {
      qic_results$message <- "Ingen run-metrics tilg\u00e6ngelige"
    }
    return(qic_results)
  }

  # 3) Ingen metrics og centerline uaendret -> bevar tidligere gyldige
  if (!is.null(previous) && is.list(previous) && isTRUE(previous$has_valid_data)) {
    return(previous)
  }

  # 4) Fallback: ingen tidligere gyldige vaerdier - returner NA-resultaterne
  qic_results$has_valid_data <- FALSE
  if (is.null(qic_results$message)) {
    qic_results$message <- "Ingen run-metrics tilg\u00e6ngelige"
  }
  return(qic_results)
}
