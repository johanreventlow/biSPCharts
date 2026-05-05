# fct_spc_plot_generation.R
# Main SPC plot generation orchestration via BFHcharts (post ADR-015)
# Extracted from fct_spc_calculations.R for better maintainability.
# NB: Legacy qicharts2 plot-generation helpers were removed in Wave 5 (#555).
# Runtime plotting goes through BFHcharts; local qicharts2 use is limited to
# Anhoej metadata extraction in the BFH signal layer.
#
# Dependencies ----------------------------------------------------------------

#' Backend Wrapper for SPC Plot Generation (BFHcharts Only)
#'
#' Routes to BFHchart backend for all supported chart types.
#' This wrapper preserves the existing generateSPCPlot() interface, ensuring
#' zero changes required in mod_spc_chart_server.R.
#'
#' **Note:** This is a pure BFHcharts implementation. qicharts2 is used only
#' for Anhoej rules metadata extraction (internal). No fallback to qicharts2
#' visualization occurs.
#'
#' @inheritParams generateSPCPlot
#' @param plot_context Character. Plot context identifier (default
#'   "analysis"). Valid contexts: "analysis", "export_preview",
#'   "export_pdf", "export_png". Context determines cache
#'   isolation and enables context-aware label placement. Use PLOT_CONTEXTS
#'   constants from config_plot_contexts.R.
#' @param override_dpi Numeric. Override DPI for dimension conversion
#'   (optional). Issue #64: Allows PNG export to use user-selected DPI
#'   instead of context default. If NULL, uses DPI from plot_context
#'   configuration.
#' @return List with plot and qic_data (from BFHcharts backend)
#' @keywords internal
generateSPCPlot_with_backend <- function(data, config, chart_type,
                                         target_value = NULL,
                                         centerline_value = NULL,
                                         show_phases = FALSE,
                                         skift_column = NULL,
                                         frys_column = NULL,
                                         chart_title_reactive = NULL,
                                         y_axis_unit = "count",
                                         kommentar_column = NULL,
                                         base_size = 14,
                                         viewport_width = NULL,
                                         viewport_height = NULL,
                                         target_text = NULL,
                                         qic_cache = NULL,
                                         app_state = NULL,
                                         plot_context = "analysis",
                                         override_dpi = NULL) {
  # Supported chart types (fra config_chart_types.R)
  supported_types <- SUPPORTED_CHART_TYPES

  # Validate plot context
  validate_plot_context(plot_context, stop_on_invalid = TRUE)

  log_info(
    component = "[BACKEND_WRAPPER]",
    message = sprintf(
      "generateSPCPlot CALLED: chart_type=%s, context=%s",
      chart_type,
      plot_context
    ),
    details = list(
      chart_type = chart_type,
      plot_context = plot_context,
      viewport_width = viewport_width,
      viewport_height = viewport_height
    )
  )

  # Validate chart type is supported
  if (!chart_type %in% supported_types) {
    stop(sprintf(
      "Chart type '%s' is not supported in BFHcharts. Supported types: %s",
      chart_type, paste(supported_types, collapse = ", ")
    ))
  }

  # Convert viewport dimensions from pixels to inches
  # BFHcharts expects width/height in inches, not pixels
  # Use context-specific DPI for correct conversion
  # Issue #64: Allow override_dpi for user-configured PNG export
  context_dims <- get_context_dimensions(
    plot_context,
    override_dpi = override_dpi
  )
  dpi <- context_dims$dpi

  viewport_width_inches <- if (!is.null(viewport_width)) {
    viewport_width / dpi
  } else {
    NULL
  }
  viewport_height_inches <- if (!is.null(viewport_height)) {
    viewport_height / dpi
  } else {
    NULL
  }

  log_debug(
    component = "[PLOT_GENERATION]",
    message = "Viewport dimension conversion",
    details = list(
      plot_context = plot_context,
      override_dpi = override_dpi,
      effective_dpi = dpi,
      width_px = viewport_width,
      height_px = viewport_height,
      width_inches = viewport_width_inches,
      height_inches = viewport_height_inches
    )
  )

  # Normaliser config-v\u00e6rdier: character(0) og tomme strings behandles som NULL
  # via sanitize_selection() (utils_ui_ui_helpers.R) der har samme kontrakt.
  x_col_val <- sanitize_selection(config$x_col)
  y_col_val <- sanitize_selection(config$y_col)
  n_col_val <- sanitize_selection(config$n_col)

  # Fallback: hvis x_col er NULL (fx character(0) fra UI), inj\u00e9r r\u00e6kkenummer som x-akse
  # S\u00e5 backend ikke fejler p\u00e5 manglende x_var -- standard SPC-adf\u00e6rd n\u00e5r x ikke er specificeret.
  # Navnet bruger ikke leading dot fordi BFHcharts' column-name-validator afviser
  # navne der ikke starter med bogstav (regex ^[a-zA-Z][a-zA-Z0-9._]*$).
  if (is.null(x_col_val) && is.data.frame(data) && nrow(data) > 0) {
    data[["spc_row_index"]] <- seq_len(nrow(data))
    x_col_val <- "spc_row_index"
  }

  # Denominator pre-filter: fjern raekker med ugyldige n-vaerdier
  # BFHcharts 0.9.0+ kaster hard error ved n <= 0, Inf, NA, eller y > n (P/PP)
  n_dropped_denom <- 0L
  if (!is.null(n_col_val) && n_col_val %in% names(data) &&
    chart_type %in% c("p", "pp", "u", "up")) {
    # parse_danish_number haandterer "50,0" -> 50 korrekt (as.numeric ville give NA)
    n_vals <- suppressWarnings(parse_danish_number(data[[n_col_val]]))
    bad_rows <- is.na(n_vals) | n_vals <= 0 | is.infinite(n_vals)
    if (chart_type %in% c("p", "pp") && !is.null(y_col_val) && y_col_val %in% names(data)) {
      y_vals <- suppressWarnings(parse_danish_number(data[[y_col_val]]))
      bad_rows <- bad_rows | (!is.na(y_vals) & !is.na(n_vals) & y_vals > n_vals)
    }
    n_dropped_denom <- sum(bad_rows)
    if (n_dropped_denom > 0) {
      data <- data[!bad_rows, ]
      log_warn(
        sprintf("Denominator pre-filter: %d r\u00e6kker fjernet (n<=0, Inf, NA, eller y>n)", n_dropped_denom),
        .context = "BFH_SERVICE"
      )
    }
  }

  # Call BFHchart backend (compute_spc_results_bfh from Task #31)
  # Adapter: Map config object to individual parameters
  result <- tryCatch(
    {
      compute_spc_results_bfh(
        data = data,
        x_var = x_col_val,
        y_var = y_col_val,
        chart_type = chart_type,
        n_var = n_col_val,
        cl_var = NULL, # Not currently supported in biSPCharts
        freeze_var = frys_column,
        part_var = if (isTRUE(show_phases) && !is.null(skift_column)) skift_column else NULL,
        notes_column = kommentar_column,
        multiply = 1, # No scaling needed, handled in y_axis_unit
        # Pass through additional BFHcharts parameters from config
        target_value = target_value,
        target_text = target_text,
        centerline_value = centerline_value,
        chart_title_reactive = chart_title_reactive,
        y_axis_unit = y_axis_unit,
        # CRITICAL: Pass viewport dimensions in INCHES (BFHcharts format)
        # Converted from pixels using context-specific DPI
        # units = "in" er noedvendigt saa BFHcharts ikke gaetter enheden
        # via smart_convert_to_inches (som fejlagtigt antager cm for 10-100 range)
        width = viewport_width_inches,
        height = viewport_height_inches,
        units = "in",
        # Issue #284: app_state required for cache layer (read_spc_cache/write_spc_cache).
        # Uden app_state er cache no-op og hver kald rekomputerer fra bunden.
        app_state = app_state
      )
    },
    error = function(e) {
      log_error(
        component = "[BACKEND_WRAPPER]",
        message = "BFHchart backend failed",
        details = list(
          error = e$message,
          chart_type = chart_type
        )
      )
      stop(e) # Re-throw the error - no fallback available
    }
  )

  if (n_dropped_denom > 0 && is.list(result)) {
    if (is.null(result$metadata)) result$metadata <- list()
    result$metadata$dropped_denominator_rows <- n_dropped_denom
  }

  return(result)
}


# PLOT STYLING ===============================================================
# Moved to BFHcharts/BFHtheme - see BFHcharts:::apply_spc_theme() and BFHtheme::theme_bfh()
# Removed legacy functions: applyHospitalTheme()

#' Generate SPC Plot (Legacy Alias)
#'
#' Legacy alias for generateSPCPlot_with_backend(). Maintains backward
#' compatibility with existing code while enabling feature flag switching.
#'
#' @inheritParams generateSPCPlot_with_backend
#' @keywords internal
generateSPCPlot <- generateSPCPlot_with_backend
