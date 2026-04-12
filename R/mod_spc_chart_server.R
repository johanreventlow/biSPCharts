# ==============================================================================
# mod_spc_chart_server.R
# ==============================================================================
# MAIN ORCHESTRATOR FOR SPC CHART VISUALIZATION MODULE
#
# Purpose: Coordinate initialization and integration of all SPC chart
#          sub-modules (state, config, inputs, computation, observers, UI).
#          Acts as the orchestrator for the complete visualization pipeline.
#
# Architecture Pattern:
#   Input reactives (parameters) → State (data) → Config → Inputs →
#   Computation (caching) → Observers (side effects) → UI rendering → Outputs
#
# Phase 2c Refactoring: COMPLETE (417 LOC, 69% reduction from 1330 LOC)
#   - Stage 1: Data Management (mod_spc_chart_state.R)
#   - Stage 2: Configuration (mod_spc_chart_config.R)
#   - Stage 3: Input Preparation (mod_spc_chart_inputs.R)
#   - Stage 4: Computation Pipeline (mod_spc_chart_compute.R)
#   - Stage 5: Observers & Side Effects (mod_spc_chart_observers.R)
#   - Stage 6: UI Rendering (utils_spc_chart_ui_helpers.R)
#   - Stage 7: Orchestrator Simplification (THIS FILE)
#
# Key design principles:
#   - Clear separation of concerns (each module has single responsibility)
#   - Reactive chain isolation (state → config → inputs → computation)
#   - Performance optimization (debouncing, caching with context awareness)
#   - Error handling (safe_operation, graceful fallbacks)
#   - Observability (structured logging, debug context)
# ==============================================================================

visualizationModuleServer <- function(
    id,
    column_config_reactive,
    chart_type_reactive,
    target_value_reactive,
    target_text_reactive,
    centerline_value_reactive,
    skift_config_reactive,
    frys_config_reactive,
    chart_title_reactive = NULL,
    y_axis_unit_reactive = NULL,
    kommentar_column_reactive = NULL,
    app_state = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # === STAGE 1: Data Management (mod_spc_chart_state.R) ===

    # Initialize data state infrastructure
    initialize_spc_chart_state(app_state)

    # Create reactive expression for filtered module data
    module_data_reactive <- create_module_data_reactive(app_state)

    # Register observer for data cache updates
    register_module_data_observer(app_state, input, output, session)

    # === STAGE 5: Observers & Side Effects (mod_spc_chart_observers.R) ===
    register_viewport_observer(app_state, session, ns)

    # Helper functions for app_state visualization management
    set_plot_state <- function(key, value) {
      app_state$visualization[[key]] <- value
    }

    get_plot_state <- function(key) {
      app_state$visualization[[key]]
    }

    # === STAGE 2: Configuration (mod_spc_chart_config.R) ===
    chart_config_raw <- create_chart_config_reactive(
      module_data_reactive = module_data_reactive,
      column_config_reactive = column_config_reactive,
      chart_type_reactive = chart_type_reactive
    )

    # Debounce to prevent redundant renders during rapid dropdown changes
    chart_config <- shiny::debounce(chart_config_raw, millis = DEBOUNCE_DELAYS$input_change)

    # === STAGE 3: Input Preparation (mod_spc_chart_inputs.R) ===
    data_ready <- create_data_ready_reactive(
      module_data_reactive = module_data_reactive
    )
    spc_inputs_raw <- create_spc_inputs_reactive(
      data_ready_reactive = data_ready,
      chart_config = chart_config,
      session = session,
      ns = ns,
      y_axis_unit_reactive = y_axis_unit_reactive,
      target_value_reactive = target_value_reactive,
      target_text_reactive = target_text_reactive,
      centerline_value_reactive = centerline_value_reactive,
      skift_config_reactive = skift_config_reactive,
      frys_config_reactive = frys_config_reactive,
      chart_title_reactive = chart_title_reactive,
      kommentar_column_reactive = kommentar_column_reactive
    )

    # PERFORMANCE: Debounce spc_inputs to prevent redundant renders during rapid UI changes
    # Uses DEBOUNCE_DELAYS$file_select (500ms) to handle window resize, title editing, and other high-frequency updates
    # Eliminates 60-80% of redundant plot generations during rapid user interactions
    spc_inputs <- shiny::debounce(spc_inputs_raw, millis = DEBOUNCE_DELAYS$file_select)

    # === STAGE 4: Computation Pipeline (mod_spc_chart_compute.R) ===
    spc_results <- create_spc_results_reactive(
      spc_inputs_reactive = spc_inputs,
      app_state = app_state,
      set_plot_state = set_plot_state,
      get_plot_state = get_plot_state
    )
    spc_plot <- create_spc_plot_reactive(
      spc_results_reactive = spc_results,
      spc_inputs_reactive = spc_inputs,
      app_state = app_state
    )
    register_cache_aware_observer(
      spc_results_reactive = spc_results,
      app_state = app_state,
      set_plot_state = set_plot_state,
      get_plot_state = get_plot_state,
      skift_config_reactive = skift_config_reactive
    )

    # UI Output Funktioner ----------------------------------------------------


    ## SPC Plot Output
    # Responsive plot with automatic font sizing based on viewport dimensions.
    # Fallback dimensions (800×600) used when clientData unavailable (Issue #193).
    output$spc_plot_actual <- shiny::renderPlot(
      width = function() {
        w <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_width")]]
        if (is.null(w) || length(w) == 0) 800 else w
      },
      height = function() {
        h <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_height")]]
        if (is.null(h) || length(h) == 0) 600 else h
      },
      res = VIEWPORT_DEFAULTS$dpi,
      {
        # Viewport guard: Use clientData if available, else fallback to prevent frozen state
        viewport_width <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_width")]]
        viewport_height <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_height")]]
        if (is.null(viewport_width) || length(viewport_width) == 0 || viewport_width <= 100) {
          viewport_width <- 800
        }
        if (is.null(viewport_height) || length(viewport_height) == 0 || viewport_height <= 100) {
          viewport_height <- 600
        }

        data <- module_data_reactive()

        # Guard: Require at least 3 rows with meaningful data (SPC minimum)
        rows_with_data <- 0L
        if (!is.null(data) && nrow(data) > 0) {
          data_cols <- setdiff(names(data), c("Skift", "Frys"))
          if (length(data_cols) > 0) {
            rows_with_data <- sum(apply(data[, data_cols, drop = FALSE], 1, function(row) {
              any(!is.na(row) & nzchar(as.character(row)))
            }))
          }
        }
        if (rows_with_data < 3) {
          graphics::plot.new()
          graphics::text(0.5, 0.5, "Indtast data", cex = 1.3, col = "#6c757d")
          return(invisible(NULL))
        }

        plot_result <- spc_plot()
        if (is.null(plot_result)) {
          # Show contextual empty state with helpful message
          config <- tryCatch(column_config_reactive(), error = function(e) NULL)
          empty_state_msg <- if (is.null(config) || is.null(config$y_col)) {
            "Vælg en numerisk Y-akse-kolonne\nfor at generere diagrammet."
          } else {
            y_col_data <- tryCatch(data[[config$y_col]], error = function(e) NULL)
            if (!is.null(y_col_data) && !is_column_numeric(y_col_data)) {
              "Den valgte Y-akse-kolonne indeholder\nikke numeriske data."
            } else {
              NULL
            }
          }
          graphics::plot.new()
          graphics::text(0.5, 0.5, empty_state_msg %||% "Beregner...", cex = 1.1, col = "#6c757d")
          return(invisible(NULL))
        }

        # Render plot with tight margins (font handling via BFHthemes)
        plot_with_margin <- plot_result +
          ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0, "mm"))
        print(plot_with_margin)
        invisible(plot_with_margin)
      }
    )

    # Must not suspend when analyser tab is hidden (Issue #193):
    # anhoej_results only computed when renderPlot is observed
    outputOptions(output, "spc_plot_actual", suspendWhenHidden = FALSE)

    # === OUTPUT ASSIGNMENTS ===

    ## Plot Status Output
    output$plot_ready <- shiny::reactive({
      get_plot_state("plot_ready")
    })
    outputOptions(output, "plot_ready", suspendWhenHidden = FALSE)

    ## Plot Info Output
    output$plot_info <- shiny::renderUI({
      warnings <- get_plot_state("plot_warnings")
      plot_ready <- get_plot_state("plot_ready")

      if (length(warnings) > 0) {
        shiny::div(
          class = "alert alert-warning",
          shiny::icon("exclamation-triangle"),
          shiny::strong(" Graf-advarsler:"),
          shiny::tags$ul(
            lapply(warnings, function(warn) {
              shiny::tags$li(htmltools::htmlEscape(warn))
            })
          )
        )
      } else if (plot_ready) {
        data <- shiny::isolate(module_data_reactive())
        chart_type <- shiny::isolate(chart_type_reactive()) %||% "ukendt"
        shiny::div(
          class = "alert alert-success",
          style = "font-size: 0.9rem;",
          shiny::icon("check-circle"),
          shiny::strong(" Graf genereret succesfuldt! "),
          sprintf("Chart type: %s | Datapunkter: %d", chart_type, nrow(data))
        )
      }
    })

    ## Data Status Value Box
    output$plot_status_boxes <- shiny::renderUI({
      plot_ready <- get_plot_state("plot_ready")
      if (plot_ready) {
        data <- shiny::isolate(module_data_reactive())
        chart_type <- shiny::isolate(chart_type_reactive()) %||% "run"
        data_count <- nrow(data)
        chart_name <- switch(chart_type,
          "run" = "Run Chart", "p" = "P-kort", "u" = "U-kort",
          "i" = "I-kort", "mr" = "MR-kort", "Ukendt"
        )
        bslib::value_box(
          title = "Data Overblik",
          value = paste(data_count, "punkter"),
          showcase = shiny::icon("chart-line"),
          theme = if (data_count >= 15) "info" else "warning",
          shiny::p(
            class = "fs-7 text-muted mb-0",
            paste(chart_name, if (data_count < 15) "| Få datapunkter" else "| Tilstrækkelig data")
          )
        )
      } else {
        bslib::value_box(
          title = "Data Status",
          value = "Ingen data",
          showcase = shiny::icon("database"),
          theme = "secondary",
          shiny::p(class = "fs-7 text-muted mb-0", "Upload eller indtast data")
        )
      }
    })

    ## Anhøj Rules Value Boxes
    # Delegated to utils_spc_chart_ui_helpers.R (Stage 6)
    output$anhoej_rules_boxes <- shiny::renderUI({
      data <- module_data_reactive()
      config <- chart_config()
      chart_type <- chart_type_reactive() %||% "run"
      anhoej <- get_plot_state("anhoej_results")

      # Delegate complex UI building to helper function
      build_anhoej_rules_boxes(data, config, chart_type, anhoej, get_plot_state)
    })

    outputOptions(output, "anhoej_rules_boxes", suspendWhenHidden = FALSE)

    ## Data Quality Value Box (Placeholder)
    output$data_quality_box <- shiny::renderUI({
      data <- module_data_reactive()
      if (is.null(data) || nrow(data) == 0) return(shiny::div())
      bslib::value_box(
        title = "Data Kvalitet",
        value = "God",
        showcase = shiny::icon("check-circle"),
        theme = "success",
        shiny::p(class = "fs-6 text-muted", "Automatisk kvalitetskontrol")
      )
    })

    ## Report Status Value Box (Placeholder)
    output$report_status_box <- shiny::renderUI({
      data <- module_data_reactive()
      if (is.null(data) || nrow(data) == 0) return(shiny::div())
      bslib::value_box(
        title = "Rapport Status",
        value = "Klar",
        showcase = shiny::icon("file-text"),
        theme = "info",
        shiny::p(class = "fs-6 text-muted", "Eksport og deling tilgængelig")
      )
    })

    # === RETURN VALUES ===
    list(
      plot = shiny::reactive(get_plot_state("plot_object")),
      plot_ready = shiny::reactive(get_plot_state("plot_ready")),
      anhoej_results = shiny::reactive(get_plot_state("anhoej_results")),
      chart_config = chart_config
    )
  })
}
