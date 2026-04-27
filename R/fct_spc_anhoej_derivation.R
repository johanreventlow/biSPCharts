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

#' Udled Anhoej-resultater per part fra QIC-data
#'
#' Itererer over unikke part-værdier i `qic_data` og kalder
#' `derive_anhoej_results()` på hvert subset. Returnerer én record per part
#' med samme felter som `derive_anhoej_results()` plus en `$part`-identifier.
#'
#' Funktionen er ren: ingen Shiny-afhængighed, ingen `app_state`-reads,
#' ingen side-effekter. Bevarer rækkefølgen som parts optræder i input-data.
#'
#' @param qic_data data.frame. QIC-data som returneret af `qicharts2::qic()`
#'   eller BFHcharts. Hvis kolonnen `part` mangler eller kun indeholder NA,
#'   behandles hele datasættet som én "part 1".
#'
#' @return list. Én element per unik part. Hvert element er en named list
#'   med felter fra `derive_anhoej_results()` udvidet med:
#'   \describe{
#'     \item{part}{integer. Part-identifier (eller `1L` hvis kolonnen mangler).}
#'   }
#'   Returnerer `list()` (tom) hvis `qic_data` er tom.
#'
#' @examples
#' \dontrun{
#' qic_result <- qicharts2::qic(month, infections,
#'   n = patients, x.period = "month",
#'   data = hospital_data, chart = "p", part = 12, return.data = TRUE
#' )
#' per_part <- derive_anhoej_per_part(qic_result)
#' length(per_part) # antal parts
#' per_part[[1]]$runs_signal # part 1's serielængde-signal
#' }
#'
#' @keywords internal
derive_anhoej_per_part <- function(qic_data) {
  stopifnot(is.data.frame(qic_data))

  if (nrow(qic_data) == 0L) {
    return(list())
  }

  has_part_col <- "part" %in% names(qic_data) &&
    !all(is.na(qic_data$part))

  if (!has_part_col) {
    result <- derive_anhoej_results(qic_data, show_phases = FALSE)
    result$part <- 1L
    # Sortér felter så $part står først (bevarer øvrig kontrakt)
    return(list(result[c("part", setdiff(names(result), "part"))]))
  }

  # Bevar rækkefølge som parts optræder i input-data (ikke numerisk sort).
  part_order <- unique(qic_data$part[!is.na(qic_data$part)])

  lapply(part_order, function(p) {
    subset_data <- qic_data[!is.na(qic_data$part) & qic_data$part == p, ]
    result <- derive_anhoej_results(subset_data, show_phases = FALSE)
    result$part <- as.integer(p)
    result[c("part", setdiff(names(result), "part"))]
  })
}

#' Tolk Anhoej signal-flag som dansk klinisk-venlig tekst
#'
#' Mapper kombinationen af `runs_signal` + `crossings_signal` til en
#' kort dansk tekst, der kan vises direkte i Excel-eksport, UI eller
#' rapport-generering.
#'
#' @param anhoej_result named list. Forventer felterne `runs_signal` og
#'   `crossings_signal` (logical). Manglende eller `NA`-værdier behandles
#'   som `FALSE`.
#'
#' @return character. En af fire mulige strenge:
#'   \itemize{
#'     \item `"Stabil proces (ingen særskilt årsag)"` — ingen signaler
#'     \item `"Særskilt årsag: lang serie"` — kun `runs_signal`
#'     \item `"Særskilt årsag: for få mediankryds"` — kun `crossings_signal`
#'     \item `"Særskilt årsag: lang serie + få kryds"` — begge signaler
#'   }
#'
#' @examples
#' \dontrun{
#' anhoej <- derive_anhoej_results(qic_result, show_phases = FALSE)
#' interpret_anhoej_signal_da(anhoej)
#' # "Stabil proces (ingen særskilt årsag)"
#' }
#'
#' @keywords internal
interpret_anhoej_signal_da <- function(anhoej_result) {
  to_logical <- function(x) {
    isTRUE(!is.null(x) && !is.na(x) && as.logical(x))
  }
  runs <- to_logical(anhoej_result$runs_signal)
  crossings <- to_logical(anhoej_result$crossings_signal)

  if (runs && crossings) {
    "Særskilt årsag: lang serie + få kryds"
  } else if (runs) {
    "Særskilt årsag: lang serie"
  } else if (crossings) {
    "Særskilt årsag: for få mediankryds"
  } else {
    "Stabil proces (ingen særskilt årsag)"
  }
}
