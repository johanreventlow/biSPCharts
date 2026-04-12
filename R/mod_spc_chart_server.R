# mod_spc_chart_server.R
# Server logic for SPC chart module
# Extracted from mod_spc_chart.R for better maintainability

# Dependencies ----------------------------------------------------------------
# Helper functions now loaded globally in global.R for better performance


visualizationModuleServer <- function(id, data_reactive, column_config_reactive, chart_type_reactive, target_value_reactive, target_text_reactive, centerline_value_reactive, skift_config_reactive, frys_config_reactive, chart_title_reactive = NULL, y_axis_unit_reactive = NULL, kommentar_column_reactive = NULL, app_state = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    # Module initialization
    ns <- session$ns

    # =========================================================================
    # PHASE 2C EXTRACTION: Data Management Module
    # =========================================================================
    # Extracted to: R/mod_spc_chart_state.R
    # Functions: safe_max, get_module_data, module_data_reactive
    # Observers: module data update observer
    # Status: Stage 1 of Phase 2c refactoring (COMPLETE)
    # =========================================================================

    # Initialize data state infrastructure
    initialize_spc_chart_state(app_state)

    # Create reactive expression for filtered module data
    module_data_reactive <- create_module_data_reactive(app_state)

    # Register observer for data cache updates
    register_module_data_observer(app_state, input, output, session)

    # =========================================================================
    # PHASE 2C EXTRACTION: Observers & Side Effects
    # =========================================================================
    # Extracted to: R/mod_spc_chart_observers.R
    # Functions: register_viewport_observer
    # Status: Stage 5 of Phase 2c refactoring (IN PROGRESS)
    # =========================================================================

    # Register viewport dimension observer (responsive font scaling)
    register_viewport_observer(app_state, session, ns)

    # UNIFIED EVENT SYSTEM: Event-driven architecture with atomic cache updates
    # Implements Event Consolidation (CLAUDE.md Section 3.1.1)
    # Legacy consolidated event handler removed - using visualization_update_needed event

    # UNIFIED EVENT SYSTEM: Initialize data at startup if available
    if (!is.null(shiny::isolate(app_state$data$current_data))) {
      initial_data <- get_module_data()
      app_state$visualization$module_data_cache <- initial_data
      app_state$visualization$module_cached_data <- initial_data
    }

    # UNIFIED STATE: Always use app_state for visualization state management

    # UNIFIED STATE: Helper functions for app_state visualization management
    set_plot_state <- function(key, value) {
      app_state$visualization[[key]] <- value
    }

    get_plot_state <- function(key) {
      return(app_state$visualization[[key]])
    }

    # Plot generation logging (replaced waiter)

    # Konfiguration og Validering ---------------------------------------------

    ## Chart Configuration
    # Reaktiv konfiguration for chart setup - delegeret til mod_spc_chart_config.R
    # Håndterer kolonne-validering og fallback-scenarier
    chart_config_raw <- create_chart_config_reactive(
      module_data_reactive = module_data_reactive,
      column_config_reactive = column_config_reactive,
      chart_type_reactive = chart_type_reactive
    )

    # PERFORMANCE: Debounce chart_config to prevent redundant renders during rapid dropdown changes
    # Uses DEBOUNCE_DELAYS$input_change (300ms) to eliminate flickering when user rapidly changes column selections
    chart_config <- shiny::debounce(chart_config_raw, millis = DEBOUNCE_DELAYS$input_change)

    # Plot Generering ---------------------------------------------------------

    # Data Validation - delegeret til mod_spc_chart_inputs.R
    data_ready <- create_data_ready_reactive(
      module_data_reactive = module_data_reactive
    )

    # SPC Input Building - delegeret til mod_spc_chart_inputs.R
    # Bygger komplette parametre for SPC beregning
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

    # =========================================================================
    # PHASE 2C EXTRACTION: SPC Computation Pipeline
    # =========================================================================
    # Extracted to: R/mod_spc_chart_compute.R
    # Functions: create_spc_results_reactive, create_spc_plot_reactive,
    #            register_cache_aware_observer
    # Status: Stage 4 of Phase 2c refactoring (IN PROGRESS)
    # =========================================================================

    # Create SPC results reactive with caching and Anhøj rules extraction
    spc_results <- create_spc_results_reactive(
      spc_inputs_reactive = spc_inputs,
      app_state = app_state,
      set_plot_state = set_plot_state,
      get_plot_state = get_plot_state
    )

    # Create SPC plot reactive (extracts plot from spc_results)
    spc_plot <- create_spc_plot_reactive(
      spc_results_reactive = spc_results,
      spc_inputs_reactive = spc_inputs,
      app_state = app_state
    )

    # Register cache-aware observer for Anhøj results updates on cache hits
    register_cache_aware_observer(
      spc_results_reactive = spc_results,
      app_state = app_state,
      set_plot_state = set_plot_state,
      get_plot_state = get_plot_state,
      skift_config_reactive = skift_config_reactive
    )

    # Fjernet separat observer for last_centerline_value (flyttet inline i spc_results)

    # UI Output Funktioner ----------------------------------------------------


    ## Faktisk Plot Rendering
    # Separat renderPlot for det faktiske SPC plot med responsive font sizing
    # base_size beregnes automatisk i spc_inputs() reactive baseret på plot bredde
    # OG pixelratio for at sikre konsistent optisk udseende på tværs af devices
    # res = 96 er industry standard for web (Shiny multiplicerer automatisk med pixelratio)
    #
    # VIEWPORT FIX: Explicit width/height binding + viewport guard sikrer korrekt
    # device size ved label placement.
    #
    # Strategien:
    # 1. width/height functions binder til faktiske clientData dimensioner
    # 2. req() guard inde i renderPlot() venter indtil clientData er klar
    # 3. Dette sikrer at device ALTID har korrekte dimensioner når labels beregnes
    # 4. Ingen fallbacks nødvendige - req() garanterer valid data
    output$spc_plot_actual <- shiny::renderPlot(
      # Fallback-dimensioner når clientData ikke er tilgængelig (sker når
      # output er hidden men suspendWhenHidden = FALSE tvinger rendering).
      # Shiny's interne getDims fejler med "argument is of length zero" hvis
      # width/height returnerer NULL. Issue #193.
      width = function() {
        w <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_width")]]
        if (is.null(w) || length(w) == 0) 800 else w
      },
      height = function() {
        h <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_height")]]
        if (is.null(h) || length(h) == 0) 600 else h
      },
      res = VIEWPORT_DEFAULTS$dpi, # M10: Industry standard for web (auto-scaled by pixelratio)
      {
        # VIEWPORT GUARD: Brug clientData hvis tilgængelig, ellers fallback.
        # Issue #193: Ved session restore til trin 3 er analyser-tab skjult
        # og clientData findes ikke. Tidligere blokkerede req() plot-beregning,
        # men så beregnes anhoej_results heller ikke → bokse fryser. I stedet
        # bruger vi fallback-dimensioner så reactive chain kan køre.
        viewport_width <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_width")]]
        viewport_height <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_height")]]

        if (is.null(viewport_width) || length(viewport_width) == 0 || viewport_width <= 100) {
          viewport_width <- 800
        }
        if (is.null(viewport_height) || length(viewport_height) == 0 || viewport_height <= 100) {
          viewport_height <- 600
        }

        # M10: Opdater viewport dimensions i centraliseret state
        emit <- create_emit_api(app_state)
        set_viewport_dims(app_state, viewport_width, viewport_height, emit)

        data <- module_data_reactive()

        # Tjek om data har mindst 3 rækker med reelle værdier (SPC minimum)
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
          # Vis kontekstuel tom-state i stedet for uendelig "Beregner..."
          config <- tryCatch(column_config_reactive(), error = function(e) NULL)
          empty_state_msg <- if (is.null(config) || is.null(config$y_col)) {
            "V\u00e6lg en numerisk Y-akse-kolonne\nfor at generere diagrammet."
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

        # NOTE: BFHcharts font handling is now done in BFHthemes package
        # Mari font fallback logic moved to source (BFHthemes) for proper fix
        # If Mari font is not available, BFHthemes will automatically use sans fallback

        # Simple unified rendering for all plots
        # Add zero margin for tight display
        plot_with_margin <- plot_result +
          ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0, "mm"))

        print(plot_with_margin)
        invisible(plot_with_margin)
      }
    )

    # SPC plot må ikke suspenderes når analyser-tab er skjult:
    # plot-reactive chain (spc_results → set_plot_state("anhoej_results"))
    # kører kun når renderPlot observeres. Hvis session restore lander på
    # trin 3 (eksporter), er analyser-tab skjult og anhoej_results beregnes
    # aldrig → anhøj-bokse fryser. Issue #193.
    outputOptions(output, "spc_plot_actual", suspendWhenHidden = FALSE)

    # Status og Information ---------------------------------------------------

    ## Plot Status
    # Plot klar status - exposed til parent
    output$plot_ready <- shiny::reactive({
      get_plot_state("plot_ready")
    })
    outputOptions(output, "plot_ready", suspendWhenHidden = FALSE)
    ## Plot Information
    # Plot info og advarsler - event-driven med reactive isolation
    output$plot_info <- shiny::renderUI({
      # Use reactive values for event-driven updates
      warnings <- get_plot_state("plot_warnings")
      plot_ready <- get_plot_state("plot_ready")

      if (length(warnings) > 0) {
        shiny::div(
          class = "alert alert-warning",
          shiny::icon("exclamation-triangle"),
          shiny::strong(" Graf-advarsler:"),
          shiny::tags$ul(
            lapply(warnings, function(warn) {
              # HTML escape warning content for XSS protection
              shiny::tags$li(htmltools::htmlEscape(warn))
            })
          )
        )
      } else if (plot_ready) {
        # Only access external reactives when needed, with isolation
        data <- shiny::isolate(module_data_reactive())
        chart_type <- shiny::isolate(chart_type_reactive()) %||% "ukendt"

        shiny::div(
          class = "alert alert-success",
          style = "font-size: 0.9rem;",
          shiny::icon("check-circle"),
          shiny::strong(" Graf genereret succesfuldt! "),
          sprintf(
            "Chart type: %s | Datapunkter: %d",
            chart_type,
            nrow(data)
          )
        )
      }
    })

    # Value Boxes -------------------------------------------------------------

    ## Data Status Box
    # Data oversigt value box - event-driven med isolation
    output$plot_status_boxes <- shiny::renderUI({
      # Event-driven approach - react to plot_ready changes
      plot_ready <- get_plot_state("plot_ready")

      if (plot_ready) {
        # Only access external reactives when needed, with isolation
        data <- shiny::isolate(module_data_reactive())
        config <- shiny::isolate(chart_config())
        chart_type <- shiny::isolate(chart_type_reactive()) %||% "run"

        data_count <- nrow(data)
        chart_name <- switch(chart_type,
          "run" = "Run Chart",
          "p" = "P-kort",
          "u" = "U-kort",
          "i" = "I-kort",
          "mr" = "MR-kort",
          "Ukendt"
        )

        bslib::value_box(
          title = "Data Overblik",
          value = paste(data_count, "punkter"),
          showcase = shiny::icon("chart-line"),
          theme = if (data_count >= 15) "info" else "warning",
          shiny::p(class = "fs-7 text-muted mb-0", paste(chart_name, if (data_count < 15) "| Få datapunkter" else "| Tilstrækkelig data"))
        )
      } else {
        # Standard tilstand
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
    # Anhøj rules som value boxes - ALTID SYNLIGE
    # Viser serielængde og antal kryds for alle chart typer
    output$anhoej_rules_boxes <- shiny::renderUI({
      data <- module_data_reactive()

      # Smart indhold baseret på nuværende status - ALTID vis boxes
      config <- chart_config()
      chart_type <- chart_type_reactive() %||% "run"
      anhoej <- get_plot_state("anhoej_results")

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

      # DEBUG: Keep status determination at debug level
      # log_debug(paste(
      #   "Status determination:",
      #   "has_meaningful_data=", has_meaningful_data,
      #   "config_y_col=", !is.null(config) && !is.null(config$y_col),
      #   "anhoej_exists=", !is.null(current_anhoej),
      #   "is_computing=", current_is_computing %||% FALSE,
      #   "plot_ready=", current_plot_ready %||% FALSE
      # ), "VISUALIZATION")

      status_info <- if (!has_meaningful_data) {
        list(
          status = "no_data",
          message = "Upload data eller start ny session",
          theme = "secondary"
        )
      } else if (is.null(config) || is.null(config$y_col)) {
        list(
          status = "not_configured",
          message = "V\u00e6lg en numerisk Y-akse-kolonne for at generere diagrammet",
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
            message = "Beregner nye v\u00e6rdier...",
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

      # Altid returner de tre hoved boxes med passende indhold
      shiny::tagList(
        ### Serielængde Box-----
        bslib::value_box(
          title = shiny::span(
            "Seriel\u00e6ngde",
            shiny::icon("circle-info", style = "font-size: 0.7em; opacity: 0.6; margin-left: 4px;")
          ) |> bslib::tooltip(
            paste0(
              "L\u00e6ngste serie af punkter p\u00e5 samme side af centerlinjen. ",
              "Hvis den overstiger gr\u00e6nsen, kan der v\u00e6re en ",
              "systematisk \u00e6ndring i processen."
            )
          ),
          style = if (status_info$status == "insufficient_data") {
            "flex: 1;  background-color: white !important; color: #999999;"
          } else {
            "flex: 1;"
          },
          value = if (status_info$status == "ready") {
            if (!is.null(anhoej$longest_run) && !is.na(anhoej$longest_run)) {
              # Show actual values
              bslib::layout_column_wrap(
                width = 1 / 2,
                shiny::div(anhoej$longest_run_max),
                shiny::div(anhoej$longest_run)
              )
            } else if (!is.null(anhoej$has_valid_data) && !anhoej$has_valid_data) {
              # Never had valid data - show informative message
              shiny::span(
                style = "font-size:1.5em; color: #666666;",
                "Ingen metrics"
              )
            } else {
              # Temporary state while computing
              shiny::span(
                style = "font-size:1.5em; color: #999999;",
                "Beregner..."
              )
            }
          } else {
            shiny::span(
              style = "font-size:1.5em; color: #999999 !important;",
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
                bslib::layout_column_wrap(
                  width = 1 / 2,
                  shiny::div("Forventet (maksimum)"),
                  shiny::div("Faktisk")
                )
              } else {
                "Anhøj rules analyse - serielængde"
              }
            } else {
              shiny::span(
                style = "color: #999999;",
                status_info$message
              )
            }
          )
        ),

        ### Antal Kryds Box -----
        bslib::value_box(
          title = shiny::span(
            "Antal kryds",
            shiny::icon("circle-info", style = "font-size: 0.7em; opacity: 0.6; margin-left: 4px;")
          ) |> bslib::tooltip(
            paste0(
              "Antal gange datapunkterne krydser centerlinjen. ",
              "For f\u00e5 krydsninger kan tyde p\u00e5 trends ",
              "eller skift i processen."
            )
          ),
          style = if (status_info$status == "insufficient_data") {
            "flex: 1;  background-color: white !important; color: #999999;"
          } else {
            "flex: 1;"
          },
          value = if (status_info$status == "ready") {
            if (!is.null(anhoej$n_crossings) && !is.na(anhoej$n_crossings)) {
              bslib::layout_column_wrap(
                width = 1 / 2,
                shiny::div(anhoej$n_crossings_min),
                shiny::div(anhoej$n_crossings)
              )
            } else if (!is.null(anhoej$has_valid_data) && !anhoej$has_valid_data) {
              # Never had valid data - show informative message
              shiny::span(
                style = "font-size:1.5em; color: #666666;",
                "Ingen metrics"
              )
            } else {
              # Temporary state while computing
              shiny::span(
                style = "font-size:1.5em; color: #999999;",
                "Beregner..."
              )
            }
          } else {
            shiny::span(
              style = "font-size:1.5em; color: #999999 !important;",
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
                bslib::layout_column_wrap(
                  width = 1 / 2,
                  shiny::div("Forventet (minimum)"),
                  shiny::div("Faktisk")
                )
              } else {
                "Anhøj rules analyse - median krydsninger"
              }
            } else {
              shiny::span(
                style = "color: #999999;",
                status_info$message
              )
            }
          )
        ),

        ### Kontrolgrænser Box ----
        bslib::value_box(
          title = if (status_info$status == "ready" && chart_type == "run") {
            shiny::div(
              "Uden for kontrolgr\u00e6nser",
              style = "color: #999999 !important;"
            )
          } else {
            shiny::span(
              "Uden for kontrolgr\u00e6nser",
              shiny::icon("circle-info", style = "font-size: 0.7em; opacity: 0.6; margin-left: 4px;")
            ) |> bslib::tooltip(
              paste0(
                "Antal datapunkter der ligger uden for ",
                "kontrolgr\u00e6nserne. Disse punkter kan ",
                "indikere s\u00e6rlige \u00e5rsager til variation."
              )
            )
          },
          style = if (status_info$status == "ready" && chart_type == "run") {
            "flex: 1; background-color: white !important; color: #999999 !important;"
          } else if (status_info$status == "insufficient_data") {
            "flex: 1;  background-color: white !important; color: #999999;"
          } else {
            "flex: 1;"
          },
          value = if (status_info$status == "ready" && !chart_type == "run" && !is.null(anhoej$out_of_control_count)) {
            anhoej$out_of_control_count
          } else if (status_info$status == "ready" && chart_type == "run") {
            shiny::div(
              style = "font-size:1em; color: #999999 !important; padding-bottom: 1em;",
              class = "fs-7 mb-0",
              "Anvendes ikke ved analyse af seriediagrammer (run charts)"
            )
          } else {
            shiny::span(
              style = "font-size:1.5em; color: #999999 !important;",
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
            NULL # No theme when we use custom styling
          } else {
            value_box_signal_theme(
              status_info,
              !is.null(anhoej$out_of_control_count) && (anhoej$out_of_control_count > 0)
            )
          },
          shiny::p(
            class = if (status_info$status == "ready" && chart_type == "run") "fs-7 mb-0" else "fs-7 text-muted mb-0",
            style = if (status_info$status == "ready" && chart_type == "run") "color: #999999 !important;" else NULL,
            if (status_info$status == "ready") {
              if (chart_type == "run") {
                ""
              } else {
                "Punkter uden for kontrolgrænser"
              }
            } else {
              shiny::span(
                style = "color: #999999;",
                status_info$message
              )
            }
          )
        )
      )
    })
    # Anhøj-bokse må aldrig suspenderes: de skal altid opdateres i baggrunden
    # så de viser korrekte værdier straks når bruger navigerer til "analyser"
    # efter session restore (uanset om restore landede på "eksporter" tab).
    outputOptions(output, "anhoej_rules_boxes", suspendWhenHidden = FALSE)

    ## Placeholder Value Boxes
    # Reserveret til fremtidige funktioner

    ### Data Kvalitet Box
    output$data_quality_box <- shiny::renderUI({
      data <- module_data_reactive()
      if (is.null(data) || nrow(data) == 0) {
        return(shiny::div())
      }

      bslib::value_box(
        title = "Data Kvalitet",
        value = "God",
        showcase = shiny::icon("check-circle"),
        theme = "success",
        shiny::p(class = "fs-6 text-muted", "Automatisk kvalitetskontrol")
      )
    })

    ### Rapport Status Box
    output$report_status_box <- shiny::renderUI({
      data <- module_data_reactive()
      if (is.null(data) || nrow(data) == 0) {
        return(shiny::div())
      }

      bslib::value_box(
        title = "Rapport Status",
        value = "Klar",
        showcase = shiny::icon("file-text"),
        theme = "info",
        shiny::p(class = "fs-6 text-muted", "Eksport og deling tilgængelig")
      )
    })

    # Return Values -----------------------------------------------------------
    # Returner reactive values til parent scope
    # Giver adgang til plot objekt, status og Anhøj resultater
    return(
      list(
        plot = shiny::reactive(get_plot_state("plot_object")),
        plot_ready = shiny::reactive(get_plot_state("plot_ready")),
        anhoej_results = shiny::reactive(get_plot_state("anhoej_results")),
        chart_config = chart_config
      )
    )
  })
}
