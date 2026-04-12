# ==============================================================================
# mod_spc_chart_inputs.R
# ==============================================================================
# SPC INPUT PREPARATION MODULE FOR SPC CHART VISUALIZATION
#
# Purpose: Build complete SPC parameter object from filtered data and user
#          selections. Handles complex parameter mapping, validates input
#          dependencies, and prepares data for BFHcharts computation.
#
# Extracted from: mod_spc_chart_server.R (Stage 3 of Phase 2c refactoring)
# Depends on: module_data_reactive (from mod_spc_chart_state)
#            chart_config (from mod_spc_chart_config, debounced)
#            Multiple input reactives (passed as arguments)
#            session (for clientData dimensions)
# ==============================================================================

#' Create Data Ready Reactive
#'
#' Validates that data meets minimum requirements for SPC charting:
#' - Data exists and is non-empty
#' - At least 3 rows with actual values
#' - Excludes purely control columns (Skift, Frys)
#'
#' @param module_data_reactive Reactive expression returning filtered data frame
#'
#' @return Reactive expression returning data frame if valid, or NULL if validation fails
#'
#' @details
#' Validation flow:
#' 1. Check data is truthy (not NULL, not empty)
#' 2. Check at least 3 rows exist
#' 3. Count rows with actual values (excluding Skift/Frys metadata columns)
#' 4. Ensure at least 3 rows have real data
#' 5. Return data if all checks pass
#'
#' @keywords internal
create_data_ready_reactive <- function(module_data_reactive) {
  shiny::reactive({
    data <- module_data_reactive()
    shiny::req(shiny::isTruthy(data))
    shiny::req(nrow(data) > 0)
    # Guard: kræv mindst 3 rækker med reelle data (SPC kræver minimum 3 punkter)
    data_cols <- setdiff(names(data), c("Skift", "Frys"))
    if (length(data_cols) > 0) {
      rows_with_values <- sum(apply(data[, data_cols, drop = FALSE], 1, function(row) {
        any(!is.na(row) & nzchar(as.character(row)))
      }))
      shiny::req(rows_with_values >= 3)
    }
    data
  })
}

#' Create SPC Inputs Reactive
#'
#' Builds complete parameter object for SPC computation. Maps user selections
#' to BFHcharts API parameters, handles chart type-specific configuration,
#' and includes viewport dimensions for responsive font scaling.
#'
#' @param data_ready_reactive Reactive expression returning validated data
#' @param chart_config Debounced reactive returning chart configuration
#' @param session Shiny session object (for clientData access)
#' @param ns Namespace function for input IDs
#' @param y_axis_unit_reactive Reactive expression for Y-axis unit (optional)
#' @param target_value_reactive Reactive expression for target value (optional)
#' @param target_text_reactive Reactive expression for target text (optional)
#' @param centerline_value_reactive Reactive expression for centerline (optional)
#' @param skift_config_reactive Reactive expression for shift/phase config (optional)
#' @param frys_config_reactive Reactive expression for freeze column (optional)
#' @param chart_title_reactive Reactive expression for chart title (optional)
#' @param kommentar_column_reactive Reactive expression for notes column (optional)
#'
#' @return Reactive expression returning list with complete SPC parameters:
#'   - data: Validated data frame
#'   - data_hash: XXHash64 of data
#'   - config: Chart configuration (x_col, y_col, n_col, chart_type)
#'   - chart_type, target_value, target_text, centerline_value
#'   - skift_config, skift_hash
#'   - frys_column, frys_hash
#'   - title, y_axis_unit, kommentar_column
#'   - base_size, viewport_width_px, viewport_height_px, viewport_ready
#'
#' @details
#' Complex parameter mapping includes:
#' - Chart type-specific validation (e.g., run charts with count mode clear n_col)
#' - Viewport dimension capture for responsive font scaling
#' - Responsive base font size calculation using geometric mean of viewport
#' - Debug logging of configuration state transitions
#' - Handling of optional parameters with fallback values
#'
#' @keywords internal
create_spc_inputs_reactive <- function(
    data_ready_reactive,
    chart_config,
    session,
    ns,
    y_axis_unit_reactive = NULL,
    target_value_reactive = NULL,
    target_text_reactive = NULL,
    centerline_value_reactive = NULL,
    skift_config_reactive = NULL,
    frys_config_reactive = NULL,
    chart_title_reactive = NULL,
    kommentar_column_reactive = NULL) {
  shiny::reactive({
    data <- data_ready_reactive()
    config <- chart_config()
    shiny::req(config)

    # FIX: Hent y_axis_unit tidligt for at afgøre om n_col skal cleares
    unit_value <- if (!is.null(y_axis_unit_reactive)) y_axis_unit_reactive() else "count"

    # DEBUG: Log config BEFORE n_col clearing
    log_debug_kv(
      message = "CONFIG BEFORE n_col clearing",
      chart_type = config$chart_type %||% "run",
      y_axis_unit = unit_value,
      x_col = config$x_col %||% "NULL",
      y_col = config$y_col %||% "NULL",
      n_col = config$n_col %||% "NULL",
      .context = "[DEBUG_CONFIG]"
    )

    # FIX: For run charts med y_axis_unit = "count", clear n_col fra config
    # Run charts kan kun bruge nævner (denominator) når y_axis_unit = "percent"
    # Dette forhindrer plot generation failure når bruger skifter fra percent til count
    qic_chart_type <- get_qic_chart_type(config$chart_type %||% "run")
    if (identical(qic_chart_type, "run") && identical(unit_value, "count")) {
      config$n_col <- NULL
      log_debug_kv(
        message = "Cleared n_col from config for run chart with count mode",
        chart_type = qic_chart_type,
        y_axis_unit = unit_value,
        .context = "[SPC_CONFIG]"
      )
    }

    # DEBUG: Log config AFTER n_col clearing
    log_debug_kv(
      message = "CONFIG AFTER n_col clearing",
      chart_type = config$chart_type %||% "run",
      y_axis_unit = unit_value,
      x_col = config$x_col %||% "NULL",
      y_col = config$y_col %||% "NULL",
      n_col = config$n_col %||% "NULL",
      .context = "[DEBUG_CONFIG]"
    )

    skift_config <- if (!is.null(skift_config_reactive)) skift_config_reactive() else NULL
    if (is.null(skift_config) || !is.list(skift_config)) {
      skift_config <- list(show_phases = FALSE, skift_column = NULL)
    }

    frys_column <- if (!is.null(frys_config_reactive)) frys_config_reactive() else NULL
    title_value <- if (!is.null(chart_title_reactive)) chart_title_reactive() else NULL
    kommentar_value <- if (!is.null(kommentar_column_reactive)) kommentar_column_reactive() else NULL
    target_text_value <- if (!is.null(target_text_reactive)) target_text_reactive() else NULL

    # VIEWPORT DIMENSIONS: Kræv faktiske clientData dimensioner.
    # Blokerer evaluering indtil browseren har rapporteret reelle dimensioner.
    # Eliminerer label-placering baseret på forkerte 800×600 defaults.
    width_px <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_width")]]
    height_px <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_height")]]
    shiny::req(!is.null(width_px), !is.null(height_px), width_px > 100, height_px > 100)

    if (getOption("spc.debug.label_placement", FALSE)) {
      log_debug(
        sprintf("Viewport: %d×%d px (clientData)", width_px, height_px),
        "VIEWPORT_DIMENSIONS"
      )
    }

    # Beregn responsive base_size baseret på viewport diagonal (geometric mean)
    # Konfiguration i FONT_SCALING_CONFIG (R/config_ui.R)
    #
    # VIGTIG: Vi dividerer IKKE med pixelratio fordi Shiny's renderPlot()
    # automatisk multiplicerer res med pixelratio (res = 96 * pixelratio).
    # Dette sikrer at fonts har samme visuelle størrelse på både standard
    # og Retina displays.
    #
    # GEOMETRIC MEAN APPROACH: sqrt(width_px * height_px) giver balanced scaling
    # baseret på både bredde og højde. Dette sikrer at fonts skalerer intuitivt
    # med den samlede plotstørrelse, ikke kun én dimension.
    pixelratio <- session$clientData$pixelratio %||% 1
    viewport_diagonal <- sqrt(width_px * height_px)
    base_size <- max(
      FONT_SCALING_CONFIG$min_size,
      min(FONT_SCALING_CONFIG$max_size, viewport_diagonal / FONT_SCALING_CONFIG$divisor)
    )

    # DEBUG: Log font scaling metrics for cross-device analysis
    log_info(
      component = "[FONT_SCALING]",
      message = sprintf(
        "Font metrics | width_px=%.0f | height_px=%.0f | diagonal=%.0f | pixelratio=%.2f | divisor=%d | base_size=%.2f",
        width_px, height_px, viewport_diagonal, pixelratio, FONT_SCALING_CONFIG$divisor, base_size
      )
    )

    list(
      data = data,
      data_hash = digest::digest(data, algo = "xxhash64"),
      config = config,
      chart_type = config$chart_type %||% "run",
      target_value = if (!is.null(target_value_reactive)) target_value_reactive() else NULL,
      target_text = target_text_value,
      centerline_value = if (!is.null(centerline_value_reactive)) centerline_value_reactive() else NULL,
      skift_config = skift_config,
      skift_hash = digest::digest(skift_config, algo = "xxhash64"),
      frys_column = frys_column,
      frys_hash = digest::digest(frys_column, algo = "xxhash64"),
      title = title_value,
      y_axis_unit = unit_value,
      kommentar_column = kommentar_value,
      base_size = base_size,
      viewport_width_px = width_px,
      viewport_height_px = height_px,
      viewport_ready = TRUE
    )
  })
}
