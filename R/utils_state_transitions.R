# utils_state_transitions.R
# Navngivne state-transition-helpers og central applier.
#
# Pure transition-funktioner returnerer en ændringsliste (plain R-lister).
# `apply_state_transition()` er den ENESTE funktion der må mutere app_state.
#
# Struktur: app_state har følgende reactiveValues-niveauer:
#   app_state$data, $columns, $columns$auto_detect, $columns$mappings,
#   $session, $ui, $visualization (alle environments via shiny::reactiveValues)

# PURE TRANSITIONS ============================================================

#' Transition: fil uploadet og klar til brug
#'
#' Returnerer ændringsliste til `apply_state_transition` efter succesfuld fil-upload.
#'
#' @param parsed_file `ParsedFile` S3-objekt fra `parse_file()`
#' @return Liste med state-ændringer
#' @noRd
transition_upload_to_ready <- function(parsed_file) {
  list(
    data = list(
      current_data  = parsed_file$data,
      original_data = parsed_file$data,
      file_info     = parsed_file$meta
    ),
    session = list(
      file_uploaded = TRUE,
      restoring_session = FALSE
    ),
    columns = list(
      auto_detect = list(
        in_progress = FALSE,
        completed = FALSE
      )
    ),
    ui = list(
      hide_anhoej_rules = FALSE
    )
  )
}

#' Transition: auto-detektion fuldført
#'
#' Returnerer ændringsliste efter `run_autodetect()` har kørt.
#'
#' @param result `AutodetectResult` S3-objekt fra `run_autodetect()`
#' @return Liste med state-ændringer
#' @noRd
transition_autodetect_complete <- function(result) {
  list(
    columns = list(
      auto_detect = list(
        results = result,
        last_run = result$timestamp,
        in_progress = FALSE,
        completed = TRUE
      ),
      mappings = list(
        x_column         = result$x_col,
        y_column         = result$y_col,
        n_column         = result$n_col,
        skift_column     = result$skift_col,
        frys_column      = result$frys_col,
        kommentar_column = result$kommentar_col
      )
    )
  )
}

#' Transition: visualiserings-konfiguration opdateret
#'
#' Returnerer ændringsliste efter `build_visualization_config()` har produceret en gyldig config.
#'
#' @param config `VisualizationConfig` S3-objekt fra `build_visualization_config()`
#' @return Liste med state-ændringer
#' @noRd
transition_chart_config_updated <- function(config) {
  list(
    visualization = list(
      last_valid_config = list(
        x_col      = config$x_col,
        y_col      = config$y_col,
        n_col      = config$n_col,
        chart_type = config$chart_type
      )
    )
  )
}

#' Transition: session restore fra biSPCharts gem-format
#'
#' Returnerer ændringsliste ved genindlæsning fra gemt Excel-fil (Data + Indstillinger).
#'
#' @param parsed_file `ParsedFile` S3-objekt (med `meta$saved_metadata`)
#' @return Liste med state-ændringer
#' @noRd
transition_session_restore <- function(parsed_file) {
  metadata <- parsed_file$meta$saved_metadata
  base <- transition_upload_to_ready(parsed_file)

  # Sæt restoring_session-flag og override auto_detect
  base$session$restoring_session <- TRUE
  base$columns$auto_detect$completed <- TRUE

  # Kolonne-mappings fra gemte indstillinger
  if (!is.null(metadata)) {
    mappings <- list()
    for (field in c(
      "x_column", "y_column", "n_column",
      "skift_column", "frys_column", "kommentar_column"
    )) {
      val <- metadata[[field]]
      if (is.character(val) && length(val) == 1L && !is.na(val) && nzchar(val)) {
        mappings[[field]] <- val
      }
    }
    if (length(mappings) > 0) {
      base$columns$mappings <- mappings
    }
  }

  base
}

# CENTRAL APPLIER =============================================================

#' Anvend state-transition atomisk på app_state
#'
#' Den ENESTE funktion der må mutere app_state i shim-koden.
#' Bruger rekursiv apply fordi alle sub-niveauer i biSPCharts er
#' `shiny::reactiveValues()`-objekter (environments).
#' `shiny::isolate()` sikrer at ingen observers affyres mens
#' transitionens delændringer skrives.
#'
#' @param app_state Centraliseret app state (environment/reactiveValues)
#' @param transition_result Liste med ændringer (fra en transition_*-funktion)
#' @return app_state (usynligt, muteret in-place)
#' @noRd
apply_state_transition <- function(app_state, transition_result) {
  is_state_branch <- function(value) {
    is.environment(value) || inherits(value, "reactivevalues")
  }

  apply_nested <- function(state, changes) {
    for (nm in names(changes)) {
      val <- changes[[nm]]
      if (is.list(val) && !is.data.frame(val) && is_state_branch(state[[nm]])) {
        # Sub-niveau er reactiveValues — rekursér
        apply_nested(state[[nm]], val)
      } else {
        # Leaf-node — direkte assignment
        state[[nm]] <- val
      }
    }
    invisible(state)
  }

  shiny::isolate(apply_nested(app_state, transition_result))
  invisible(app_state)
}
