# server_visualization.R
# Server logik for visualisering og data forberedelse

# Dependencies ----------------------------------------------------------------

# VISUALISERING SETUP =========================================================

## Hovedfunktion for visualisering
# Opsætter al server logik relateret til visualisering og data forberedelse
setup_visualization <- function(input, output, session, app_state) {
  # INPUT SANITIZATION: Using centralized sanitize_selection from utils_ui_helpers.R

  # UNIFIED EVENT SYSTEM: Direct access to app_state data instead of reactive dependencies
  # No need for app_data_reactive - visualization module uses its own event-driven data access

  # Kolonne konfiguration til visualisering
  # Store last valid config to avoid NULL during input updates
  # Initialize last_valid_config in app_state if not already present
  # Use isolate() to safely check reactive value outside reactive context
  current_config <- isolate(app_state$visualization$last_valid_config)
  if (is.null(current_config)) {
    app_state$visualization$last_valid_config <- list(x_col = NULL, y_col = NULL, n_col = NULL, chart_type = "run")
  }

  # Separate reactives for auto-detected and manual column selection
  auto_detected_config <- shiny::reactive({
    # Use unified state management - CORRECTED PATH
    auto_columns <- app_state$columns$auto_detect$results

    if (!is.null(auto_columns)) {
      if (!is.null(auto_columns$timestamp)) {
        # Timestamp available for logging/debugging if needed
      }
    }

    shiny::req(auto_columns)

    config <- list(
      x_col = auto_columns$x_col,
      y_col = auto_columns$y_col,
      n_col = auto_columns$n_col,
      chart_type = get_qic_chart_type(if (is.null(input$chart_type)) "Seriediagram (Run Chart)" else input$chart_type)
    )

    return(config)
  })

  manual_config <- shiny::reactive({
    x_col <- sanitize_selection(input$x_column)
    y_col <- sanitize_selection(input$y_column)
    n_col <- sanitize_selection(input$n_column)

    list(
      x_col = x_col,
      y_col = y_col,
      n_col = n_col,
      chart_type = get_qic_chart_type(if (is.null(input$chart_type)) "Seriediagram (Run Chart)" else input$chart_type)
    )
  })

  # Simplified column config via build_visualization_config() (pure)
  column_config <- shiny::reactive({
    manual_cfg <- manual_config()
    auto_columns <- app_state$columns$auto_detect$results

    # Fix #393: Under session-restore er input$chart_type stadig "run" (default)
    # fordi updateSelectizeInput() i restore_metadata endnu ikke har koert
    # (det sker i onFlushed EFTER dette reaktive laeses). Vi laeser i stedet
    # fra app_state$columns$mappings$chart_type, som skrives eksplicit i
    # session-restore-flowet foer emit$data_updated() fyrer.
    chart_type_str <- if (
      isTRUE(is_restoring_session(app_state)) &&
        !is.null(shiny::isolate(app_state$columns$mappings$chart_type)) &&
        nzchar(shiny::isolate(app_state$columns$mappings$chart_type))
    ) {
      shiny::isolate(app_state$columns$mappings$chart_type)
    } else {
      get_qic_chart_type(
        if (is.null(input$chart_type)) "Seriediagram (Run Chart)" else input$chart_type
      )
    }

    # Byg AutodetectResult-lignende objekt fra state (kan være NULL)
    autodetect_for_config <- if (!is.null(auto_columns)) {
      structure(
        list(
          x_col = auto_columns$x_col,
          y_col = auto_columns$y_col,
          n_col = auto_columns$n_col
        ),
        class = "AutodetectResult"
      )
    } else {
      NULL
    }

    # Brug pure build_visualization_config med prioriteret input
    cfg <- build_visualization_config(
      data = NULL, # kolonne-validering sker i render-laget
      autodetect = autodetect_for_config,
      user_overrides = list(
        x_col = manual_cfg$x_col,
        y_col = manual_cfg$y_col,
        n_col = manual_cfg$n_col,
        chart_type = chart_type_str,
        # Issue #193 fallback: mappings ved session-restore
        mappings = list(
          x_column = app_state$columns$mappings$x_column,
          y_column = app_state$columns$mappings$y_column,
          n_column = app_state$columns$mappings$n_column
        )
      )
    )

    if (is.null(cfg)) {
      return(NULL)
    }

    # Returner som plain liste (bagudkompatibelt med downstream reaktiver)
    list(
      x_col      = cfg$x_col,
      y_col      = cfg$y_col,
      n_col      = cfg$n_col,
      chart_type = cfg$chart_type
    )
  })

  # Observer to update last_valid_config via central applier (side effects outside reactives)
  shiny::observe({
    config <- column_config()
    if (!is.null(config$y_col)) {
      vc <- build_visualization_config(
        data = NULL,
        autodetect = NULL,
        user_overrides = list(
          x_col      = config$x_col,
          y_col      = config$y_col,
          n_col      = config$n_col,
          chart_type = config$chart_type
        )
      )
      if (!is.null(vc)) {
        apply_state_transition(app_state, transition_chart_config_updated(vc))
      }
    }
  })

  # Chart type reactive (shared by target and centerline)
  chart_type_reactive <- shiny::reactive({
    chart_selection <- if (is.null(input$chart_type)) "Seriediagram (Run Chart)" else input$chart_type
    get_qic_chart_type(chart_selection)
  })

  # Raw target text reactive (for operator parsing in labels)
  target_text_reactive <- shiny::debounce(shiny::reactive({
    if (is.null(input$target_value) || input$target_value == "") {
      return(NULL)
    }
    return(input$target_value)
  }), millis = DEBOUNCE_DELAYS$chart_update)

  # Initialiser visualiserings modul - no debouncing for valuebox stability
  # NB: Module-id "visualization" er hardcoded i inst/app/www/viewport-ready.js
  # (selectorer #visualization-spc_plot_actual + visualization-viewport_ready
  # input-id). Hvis id'et omdoebes, skal JS-filen opdateres synkront — ellers
  # silent-break af Issue #610 cold-start-gating.
  visualization <- visualizationModuleServer(
    "visualization",
    column_config_reactive = column_config,
    chart_type_reactive = chart_type_reactive,
    target_value_reactive = shiny::debounce(shiny::reactive({
      if (is.null(input$target_value) || input$target_value == "") {
        return(NULL)
      }

      trimmed_input <- trimws(input$target_value)

      # Check if input is ONLY operators (for arrow symbols)
      # In that case, return a dummy numeric value (will be ignored, only text matters)
      if (grepl("^[<>=]+$", trimmed_input)) {
        # Only operators - return a dummy value
        # The actual arrow logic will use target_text
        return(0)
      }

      # CRITICAL FIX: Strip leading operators before parsing
      # This allows "<80%" to extract "80%" for normalization
      # while target_text preserves original "<80%" for label formatting
      numeric_part <- sub("^[<>=]+", "", trimmed_input)

      # Use unified axis value processing with chart-type awareness
      chart_type <- chart_type_reactive() # Get chart type from reactive
      y_unit <- if (is.null(input$y_axis_unit) || input$y_axis_unit == "") NULL else input$y_axis_unit

      # Get Y sample data for heuristics (if no explicit user unit)
      y_sample <- NULL
      if (is.null(y_unit)) {
        data <- app_state$data$current_data
        config <- column_config()
        if (!is.null(data) && !is.null(config) && !is.null(config$y_col) && config$y_col %in% names(data)) {
          y_data <- data[[config$y_col]]
          y_sample <- parse_danish_number(y_data)
        }
      }

      # Use chart-type aware normalization (eliminates 100×-mismatch)
      # Pass numeric_part instead of original input
      return(normalize_axis_value(
        x = numeric_part,
        user_unit = y_unit,
        col_unit = NULL, # Could be added if we have column metadata
        y_sample = y_sample,
        chart_type = chart_type # This determines internal_unit automatically
      ))
    }), millis = DEBOUNCE_DELAYS$chart_update), # Debounce input changes to prevent excessive plot regeneration
    target_text_reactive = target_text_reactive,
    centerline_value_reactive = shiny::debounce(shiny::reactive({
      if (is.null(input$centerline_value) || input$centerline_value == "") {
        return(NULL)
      }

      # Use identical processing as target_value_reactive for consistency
      chart_type <- chart_type_reactive() # Get chart type from reactive
      y_unit <- if (is.null(input$y_axis_unit) || input$y_axis_unit == "") NULL else input$y_axis_unit

      # Get Y sample data for heuristics (if no explicit user unit)
      y_sample <- NULL
      if (is.null(y_unit)) {
        data <- app_state$data$current_data
        config <- column_config()
        if (!is.null(data) && !is.null(config) && !is.null(config$y_col) && config$y_col %in% names(data)) {
          y_data <- data[[config$y_col]]
          y_sample <- parse_danish_number(y_data)
        }
      }

      # Use identical chart-type aware normalization as target (prevents inconsistencies)
      return(normalize_axis_value(
        x = input$centerline_value,
        user_unit = y_unit,
        col_unit = NULL, # Could be added if we have column metadata
        y_sample = y_sample,
        chart_type = chart_type # This determines internal_unit automatically
      ))
    }), millis = DEBOUNCE_DELAYS$chart_update), # Debounce input changes to prevent excessive plot regeneration
    skift_config_reactive = shiny::reactive({
      # Bestem om vi skal vise faser baseret på Skift kolonne valg og data
      data <- app_state$data$current_data
      config <- column_config()

      if (is.null(data) || is.null(config)) {
        return(list(show_phases = FALSE, skift_column = NULL))
      }

      # Tjek om bruger har valgt en Skift kolonne - brug robust sanitization
      skift_col <- sanitize_selection(input$skift_column)

      # BUG FIX: Fallback til auto-detected Skift kolonne hvis bruger ikke har valgt noget
      if (is.null(skift_col)) {
        skift_col <- app_state$columns$mappings$skift_column
      }

      # Hvis ingen Skift kolonne valgt eller auto-detected, ingen faser
      if (is.null(skift_col) || !skift_col %in% names(data)) {
        return(list(show_phases = FALSE, skift_column = NULL))
      }

      # Tjek om Skift kolonne har nogen TRUE værdier
      skift_data <- data[[skift_col]]
      # Handle case where skift_data might be a list or non-logical type
      if (is.list(skift_data)) {
        skift_data <- unlist(skift_data)
      }
      # Convert to logical if needed
      if (!is.logical(skift_data)) {
        skift_data <- as.logical(skift_data)
      }
      has_phase_shifts <- any(skift_data == TRUE, na.rm = TRUE)

      return(list(
        show_phases = has_phase_shifts,
        skift_column = skift_col
      ))
    }),
    frys_config_reactive = shiny::reactive({
      # Bestem frys kolonne for baseline freeze
      data <- app_state$data$current_data
      config <- column_config()

      if (is.null(data) || is.null(config)) {
        return(NULL)
      }

      # Tjek om bruger har valgt en Frys kolonne - brug robust sanitization
      frys_col <- sanitize_selection(input$frys_column)

      # BUG FIX: Fallback til auto-detected Frys kolonne hvis bruger ikke har valgt noget
      if (is.null(frys_col)) {
        frys_col <- app_state$columns$mappings$frys_column
      }

      # Hvis ingen Frys kolonne valgt eller auto-detected, eller ikke i data, returner NULL
      if (is.null(frys_col) || !frys_col %in% names(data)) {
        return(NULL)
      }

      return(frys_col)
    }),
    chart_title_reactive = chart_title(input),
    y_axis_unit_reactive = shiny::reactive({
      if (is.null(input$y_axis_unit) || input$y_axis_unit == "") {
        return("count")
      } else {
        return(input$y_axis_unit)
      }
    }),
    kommentar_column_reactive = shiny::reactive({
      # Use same fallback pattern as skift_column and frys_column
      val <- sanitize_selection(input$kommentar_column)

      # BUG FIX: Fallback to auto-detected Kommentar kolonne hvis bruger ikke har valgt noget
      if (is.null(val)) {
        val <- app_state$columns$mappings$kommentar_column
      }

      return(val)
    }),
    app_state = app_state,
    emit = create_emit_api(app_state)
  )

  # Plot klar tjek
  output$plot_ready <- shiny::reactive({
    result <- !is.null(visualization$plot_ready()) && visualization$plot_ready()
    return(if (result) "true" else "false")
  })
  outputOptions(output, "plot_ready", suspendWhenHidden = FALSE)

  # Retur nér visualiserings objekt til brug i download handlers
  return(visualization)
}
