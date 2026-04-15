# ==============================================================================
# utils_spc_chart_ui_helpers.R
# ==============================================================================
# UI HELPER FUNCTIONS FOR SPC CHART VISUALIZATION
#
# Purpose: Extract complex UI building logic from mod_spc_chart_server.R
#          to keep server logic focused on reactivity and state management.
#          Provides helper functions for rendering Anhøj rules boxes and
#          status displays.
#
# Extracted from: mod_spc_chart_server.R (Stage 6 of Phase 2c refactoring)
# Depends on: chart_type_reactive (for chart type detection)
#            module_data_reactive (for data availability)
#            get_plot_state (for status and Anhøj results)
# ==============================================================================

#' Build Anhøj Rules Value Boxes
#'
#' Renders three value boxes displaying Anhøj rules analysis results:
#' Serielængde (longest run), Antal kryds (crossings), and Uden for kontrol
#' (out of control points).
#'
#' @param data Data frame with chart data
#' @param config Chart configuration with column mappings
#' @param chart_type Type of SPC chart (run, p, u, i, mr, etc.)
#' @param anhoej Anhøj results list with signal detection and metrics
#' @param get_plot_state Function to retrieve plot state values
#'
#' @return Shiny tagList containing three value_box elements
#'
#' @details
#' Box content is status-aware:
#' - No data: Shows placeholder with message
#' - Configuring: Shows "Not configured" state
#' - Calculating: Shows "Calculating..." state
#' - Ready: Shows actual metrics with signal coloring
#'
#' Anhøj-bokse må aldrig suspenderes: de skal altid opdateres i baggrunden
#' så de viser korrekte værdier straks når bruger navigerer efter session
#' restore.
#'
#' @keywords internal
build_anhoej_rules_boxes <- function(data, config, chart_type, anhoej, get_plot_state) {
  # Simplificeret logik - hvis vi har data med meningsfuldt indhold, er vi klar
  has_meaningful_data <- !is.null(data) && nrow(data) > 0 &&
    any(sapply(data, function(x) {
      if (is.logical(x)) {
        return(any(x, na.rm = TRUE))
      }
      if (is.numeric(x)) {
        return(any(!is.na(x)))
      }
      if (is.character(x)) {
        return(any(nzchar(x, keepNA = FALSE), na.rm = TRUE))
      }
      return(FALSE)
    }))

  # Bestem nuværende status og passende indhold
  current_anhoej <- get_plot_state("anhoej_results")
  current_is_computing <- get_plot_state("is_computing")
  current_plot_ready <- get_plot_state("plot_ready")

  status_info <- if (!has_meaningful_data) {
    list(
      status = "no_data",
      message = "Upload data eller start ny session",
      theme = "secondary"
    )
  } else if (is.null(config) || is.null(config$y_col)) {
    list(
      status = "not_configured",
      message = "Vælg en numerisk Y-akse-kolonne for at generere diagrammet",
      theme = "warning"
    )
  } else if (!is_column_numeric(data[[config$y_col]])) {
    list(
      status = "not_configured",
      message = "Den valgte Y-akse-kolonne indeholder ikke numeriske data",
      theme = "warning"
    )
  } else {
    # Check om vi har nok meningsfuldt data
    meaningful_count <- if (!is.null(config$n_col) && config$n_col %in% names(data)) {
      sum(!is.na(data[[config$y_col]]) & !is.na(data[[config$n_col]]) & data[[config$n_col]] > 0)
    } else {
      sum(!is.na(data[[config$y_col]]))
    }

    if (meaningful_count < 10) {
      list(
        status = "insufficient_data",
        message = "Mindst 10 datapunkter nødvendigt for SPC analyse"
      )
    } else if (get_plot_state("is_computing") %||% FALSE) {
      list(
        status = "calculating",
        message = "Beregner nye værdier...",
        theme = "info"
      )
    } else if (!(get_plot_state("plot_ready") %||% FALSE)) {
      list(
        status = "processing",
        message = "Behandler data og beregner...",
        theme = "info"
      )
    } else {
      list(
        status = "ready",
        message = "SPC analyse klar",
        theme = "success"
      )
    }
  }

  # Build the three value boxes with status-aware content
  shiny::tagList(
    ### Serielængde Box
    build_serielengde_box(status_info, anhoej),

    ### Antal Kryds Box
    build_antal_kryds_box(status_info, anhoej),

    ### Kontrolgrænser Box
    build_kontrolgraenser_box(status_info, anhoej, chart_type)
  )
}

#' Build Serielængde Value Box
#'
#' Helper to build the longest run (serielængde) value box.
#'
#' @keywords internal
build_serielengde_box <- function(status_info, anhoej) {
  muted_color <- get_hospital_colors()$ui_grey_soft
  bslib::value_box(
    title = shiny::span(
      "Serielængde",
      shiny::icon("circle-info", style = "font-size: 0.7em; opacity: 0.6; margin-left: 4px;")
    ) |> bslib::tooltip(
      "Antal p\u00e5 hinanden f\u00f8lgende punkter p\u00e5 samme side af centrallinjen. Hvis det faktiske tal overstiger det forventede, er der tegn p\u00e5 et skift i processen."
    ),
    style = if (status_info$status == "insufficient_data") {
      paste0("flex: 1; background-color: white !important; color: ", muted_color, ";")
    } else {
      "flex: 1;"
    },
    value = if (status_info$status == "ready") {
      if (!is.null(anhoej$longest_run) && !is.na(anhoej$longest_run)) {
        bslib::layout_column_wrap(width = 1 / 2, shiny::div(anhoej$longest_run_max), shiny::div(anhoej$longest_run))
      } else if (!is.null(anhoej$has_valid_data) && !anhoej$has_valid_data) {
        shiny::span(style = paste0("font-size:1.5em; color: ", muted_color, ";"), "Ingen metrics")
      } else {
        shiny::span(style = paste0("font-size:1.5em; color: ", muted_color, ";"), "Afventer data")
      }
    } else {
      shiny::span(
        style = paste0("font-size:1.5em; color: ", muted_color, " !important;"),
        switch(status_info$status,
          "no_data" = "Ingen data",
          "not_started" = "Afventer start",
          "not_configured" = "Ikke konfigureret",
          "insufficient_data" = "For få data",
          "processing" = "Behandler...",
          "calculating" = "Beregner...",
          "Afventer data"
        )
      )
    },
    showcase = spc_run_chart_icon,
    theme = value_box_signal_theme(status_info, anhoej$runs_signal),
    shiny::p(
      class = "fs-7 text-muted mb-0",
      if (status_info$status == "ready") {
        if (!is.null(anhoej$longest_run_max) && !is.na(anhoej$longest_run_max)) {
          bslib::layout_column_wrap(width = 1 / 2, shiny::div("Forventet (maksimum)"), shiny::div("Faktisk"))
        } else {
          "Anhøj rules analyse - serielængde"
        }
      } else {
        shiny::span(style = paste0("color: ", muted_color, ";"), status_info$message)
      }
    )
  )
}

#' Build Antal Kryds Value Box
#'
#' Helper to build the crossing count (antal kryds) value box.
#'
#' @keywords internal
build_antal_kryds_box <- function(status_info, anhoej) {
  muted_color <- get_hospital_colors()$ui_grey_soft
  bslib::value_box(
    title = shiny::span(
      "Antal kryds",
      shiny::icon("circle-info", style = "font-size: 0.7em; opacity: 0.6; margin-left: 4px;")
    ) |> bslib::tooltip(
      "Antal gange linjen krydser centrallinjen. Hvis det faktiske tal er lavere end det forventede, er der tegn p\u00e5 clustering eller trends i data."
    ),
    style = if (status_info$status == "insufficient_data") {
      paste0("flex: 1; background-color: white !important; color: ", muted_color, ";")
    } else {
      "flex: 1;"
    },
    value = if (status_info$status == "ready") {
      if (!is.null(anhoej$n_crossings) && !is.na(anhoej$n_crossings)) {
        bslib::layout_column_wrap(width = 1 / 2, shiny::div(anhoej$n_crossings_min), shiny::div(anhoej$n_crossings))
      } else if (!is.null(anhoej$has_valid_data) && !anhoej$has_valid_data) {
        shiny::span(style = paste0("font-size:1.5em; color: ", muted_color, ";"), "Ingen metrics")
      } else {
        shiny::span(style = paste0("font-size:1.5em; color: ", muted_color, ";"), "Afventer data")
      }
    } else {
      shiny::span(
        style = paste0("font-size:1.5em; color: ", muted_color, " !important;"),
        switch(status_info$status,
          "no_data" = "Ingen data",
          "not_started" = "Afventer start",
          "not_configured" = "Ikke konfigureret",
          "insufficient_data" = "For få data",
          "processing" = "Behandler...",
          "calculating" = "Beregner...",
          "Afventer data"
        )
      )
    },
    showcase = spc_median_crossings_icon,
    theme = value_box_signal_theme(status_info, anhoej$crossings_signal),
    shiny::p(
      class = "fs-7 text-muted mb-0",
      if (status_info$status == "ready") {
        if (!is.null(anhoej$n_crossings_min) && !is.na(anhoej$n_crossings_min)) {
          bslib::layout_column_wrap(width = 1 / 2, shiny::div("Forventet (minimum)"), shiny::div("Faktisk"))
        } else {
          "Anhøj rules analyse - median krydsninger"
        }
      } else {
        shiny::span(style = paste0("color: ", muted_color, ";"), status_info$message)
      }
    )
  )
}

#' Build Kontrolgrænser Value Box
#'
#' Helper to build the out-of-control points (kontrolgrænser) value box.
#'
#' @keywords internal
build_kontrolgraenser_box <- function(status_info, anhoej, chart_type) {
  muted_color <- get_hospital_colors()$ui_grey_soft
  bslib::value_box(
    title = if (status_info$status == "ready" && chart_type == "run") {
      shiny::div("Uden for kontrolgrænser", style = paste0("color: ", muted_color, " !important;"))
    } else {
      shiny::span(
        "Uden for kontrolgrænser",
        shiny::icon("circle-info", style = "font-size: 0.7em; opacity: 0.6; margin-left: 4px;")
      ) |> bslib::tooltip(
        "Antal datapunkter der ligger uden for kontrolgr\u00e6nserne. Disse punkter er st\u00e6rke signaler om s\u00e6rlig variation. Kun relevant for kontroldiagrammer (I-/P-/U-/C-kort)."
      )
    },
    style = if (status_info$status == "ready" && chart_type == "run") {
      paste0("flex: 1; background-color: white !important; color: ", muted_color, " !important;")
    } else if (status_info$status == "insufficient_data") {
      paste0("flex: 1; background-color: white !important; color: ", muted_color, ";")
    } else {
      "flex: 1;"
    },
    value = if (status_info$status == "ready" && !chart_type == "run" && !is.null(anhoej$out_of_control_count)) {
      anhoej$out_of_control_count
    } else if (status_info$status == "ready" && chart_type == "run") {
      shiny::div(
        style = paste0("font-size:1em; color: ", muted_color, " !important; padding-bottom: 1em;"),
        class = "fs-7 mb-0",
        "Anvendes ikke ved analyse af seriediagrammer"
      )
    } else {
      shiny::span(
        style = paste0("font-size:1.5em; color: ", muted_color, " !important;"),
        switch(status_info$status,
          "no_data" = "Ingen data",
          "not_started" = "Afventer start",
          "not_configured" = "Ikke konfigureret",
          "insufficient_data" = "For få data",
          "processing" = "Behandler...",
          "calculating" = "Beregner...",
          "Afventer data"
        )
      )
    },
    showcase = spc_out_of_control_icon,
    theme = if (status_info$status == "ready" && chart_type == "run") {
      NULL
    } else {
      value_box_signal_theme(status_info, !is.null(anhoej$out_of_control_count) && (anhoej$out_of_control_count > 0))
    },
    shiny::p(
      class = if (status_info$status == "ready" && chart_type == "run") "fs-7 mb-0" else "fs-7 text-muted mb-0",
      style = if (status_info$status == "ready" && chart_type == "run") paste0("color: ", muted_color, " !important;") else NULL,
      if (status_info$status == "ready") {
        if (chart_type == "run") "" else "Punkter uden for kontrolgrænser"
      } else {
        shiny::span(style = paste0("color: ", muted_color, ";"), status_info$message)
      }
    )
  )
}
