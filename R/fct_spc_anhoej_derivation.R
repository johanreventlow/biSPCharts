# fct_spc_anhoej_derivation.R
# Ren funktion til udledning af Anhoej-regelresultater fra qic_data.

#' Udled Anhoej-resultater fra QIC-data
#'
#' Udtrækker og beregner Anhøj serielængde- og kryds-metrics fra et
#' `qic_data`-objekt returneret af `qicharts2::qic()` eller BFHcharts.
#' Håndterer fase-filtrering internt når `show_phases = TRUE`.
#'
#' Funktionen er ren: ingen Shiny-afhængighed, ingen `app_state`-reads,
#' ingen side-effekter, ingen caching.
#'
#' @param qic_data data.frame. QIC-data med mindst kolonnerne
#'   `runs.signal`, `n.crossings`, `n.crossings.min`. Valgfrit:
#'   `longest.run`, `longest.run.max`, `part`, `y`.
#' @param show_phases logical. Hvis `TRUE` filtreres til seneste `part`
#'   før beregning (jf. `filter_latest_part()`). Default `FALSE`.
#'
#' @return list med ni felter:
#'   \describe{
#'     \item{runs_signal}{logical. `TRUE` hvis serielængde-testen er udløst
#'       (mindst ét punkt i `runs.signal` er `TRUE`).}
#'     \item{crossings_signal}{logical. `TRUE` hvis krydstesten er udløst
#'       (`n.crossings < n.crossings.min`).}
#'     \item{anhoej_signal}{logical. `TRUE` hvis enten `runs_signal` eller
#'       `crossings_signal` er `TRUE`.}
#'     \item{longest_run}{numeric. Maksimal serielængde (`longest.run`),
#'       eller `NA_real_` hvis kolonnen mangler.}
#'     \item{longest_run_max}{numeric. Maksimalt acceptabel serielængde
#'       (`longest.run.max`), eller `NA_real_` hvis kolonnen mangler.}
#'     \item{n_crossings}{numeric. Antal mediankryds observeret
#'       (`n.crossings`), eller `NA_real_` hvis kolonnen mangler.}
#'     \item{n_crossings_min}{numeric. Minimum forventet antal kryds
#'       (`n.crossings.min`), eller `NA_real_` hvis kolonnen mangler.}
#'     \item{special_cause_points}{logical vector. Per-punkt signal fra
#'       `runs.signal`-kolonnen (efter evt. fase-filtrering), eller
#'       `logical(0)` hvis kolonnen mangler.}
#'     \item{data_points_used}{integer. Antal rækker i det (evt. filtrerede)
#'       datasæt.}
#'   }
#'
#' @examples
#' \dontrun{
#' qic_result <- qicharts2::qic(month, infections,
#'   n = patients,
#'   data = hospital_data, chart = "p", return.data = TRUE
#' )
#' anhoej <- derive_anhoej_results(qic_result$data, show_phases = FALSE)
#' anhoej$anhoej_signal # TRUE/FALSE
#' anhoej$longest_run # fx 5
#' }
#'
#' @keywords internal
derive_anhoej_results <- function(qic_data, show_phases = FALSE) {
  stopifnot(is.data.frame(qic_data))

  data <- filter_latest_part(qic_data, show_phases)

  if (is.null(data) || nrow(data) == 0) {
    return(list(
      runs_signal = FALSE,
      crossings_signal = FALSE,
      anhoej_signal = FALSE,
      longest_run = NA_real_,
      longest_run_max = NA_real_,
      n_crossings = NA_real_,
      n_crossings_min = NA_real_,
      special_cause_points = logical(0),
      data_points_used = 0L
    ))
  }

  # as.double() sikrer konsistent double-type uanset input-kolonnens storage mode
  col_scalar <- function(col) {
    if (col %in% names(data)) as.double(safe_max(data[[col]])) else NA_real_
  }

  runs_signal <- if ("runs.signal" %in% names(data)) {
    any(data$runs.signal, na.rm = TRUE)
  } else {
    FALSE
  }

  crossings_signal <- if ("n.crossings" %in% names(data) && "n.crossings.min" %in% names(data)) {
    n_cross <- safe_max(data$n.crossings)
    n_cross_min <- safe_max(data$n.crossings.min)
    !is.na(n_cross) && !is.na(n_cross_min) && n_cross < n_cross_min
  } else {
    FALSE
  }

  longest_run <- col_scalar("longest.run")
  longest_run_max <- col_scalar("longest.run.max")
  n_crossings <- col_scalar("n.crossings")
  n_crossings_min <- col_scalar("n.crossings.min")
  special_cause_points <- if ("runs.signal" %in% names(data)) data$runs.signal else logical(0)

  list(
    runs_signal          = runs_signal,
    crossings_signal     = crossings_signal,
    anhoej_signal        = runs_signal || crossings_signal,
    longest_run          = longest_run,
    longest_run_max      = longest_run_max,
    n_crossings          = n_crossings,
    n_crossings_min      = n_crossings_min,
    special_cause_points = special_cause_points,
    data_points_used     = nrow(data)
  )
}
