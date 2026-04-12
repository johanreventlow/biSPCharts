# ==============================================================================
# mod_spc_chart_config.R
# ==============================================================================
# CHART CONFIGURATION MODULE FOR SPC CHART VISUALIZATION
#
# Purpose: Build chart configuration from module data and user selections.
#          Extracts column mappings, validates them against data, and provides
#          chart type configuration for downstream reactives.
#
# Extracted from: mod_spc_chart_server.R (Stage 2 of Phase 2c refactoring)
# Depends on: module_data_reactive (from mod_spc_chart_state)
#            column_config_reactive, chart_type_reactive (module arguments)
# ==============================================================================

#' Create Chart Configuration Reactive
#'
#' Builds a reactive expression that reads data and user selections to create
#' a valid chart configuration. Validates that selected columns exist in the
#' data and handles fallback scenarios gracefully.
#'
#' @param module_data_reactive Reactive expression returning filtered data frame
#' @param column_config_reactive Reactive expression returning column mappings
#' @param chart_type_reactive Reactive expression returning chart type string
#'
#' @return Reactive expression returning list with structure:
#'   - x_col: X-axis column name (typically date)
#'   - y_col: Y-axis column name (typically value)
#'   - n_col: N-values column name for subgrouped charts
#'   - chart_type: Chart type string (run, i, mr, t, p, c, u, ewma, etc.)
#'   Returns NULL if required validations fail (no data, y_col missing)
#'
#' @details
#' Validation flow:
#' 1. Check data exists and is valid (data frame with rows/columns)
#' 2. Check column config exists and is list
#' 3. Check chart type (fallback to "run" if NULL)
#' 4. Validate selected columns exist in data (fallback to NULL if missing)
#' 5. Ensure y_col is available (critical requirement)
#' 6. Return configuration or NULL
#'
#' Uses shiny::req() for early exit and safe validation to prevent hanging
#' reactive chains when dependencies are incomplete.
#'
#' @keywords internal
create_chart_config_reactive <- function(module_data_reactive, column_config_reactive, chart_type_reactive) {
  shiny::reactive({
    # Enhanced shiny::req() guards - stop execution if dependencies not ready
    data <- module_data_reactive()
    shiny::req(data)
    shiny::req(is.data.frame(data))
    shiny::req(nrow(data) > 0)
    shiny::req(ncol(data) > 0)

    config <- column_config_reactive()
    shiny::req(config)
    shiny::req(is.list(config))

    chart_type <- chart_type_reactive() %||% "run" # Use %||% for cleaner fallback
    shiny::req(chart_type)

    # Valider at kolonner eksisterer i data - hvis ikke, fallback til NULL
    if (!is.null(config$x_col) && !(config$x_col %in% names(data))) {
      config$x_col <- NULL
    }
    if (!is.null(config$y_col) && !(config$y_col %in% names(data))) {
      config$y_col <- NULL
    }
    if (!is.null(config$n_col) && !(config$n_col %in% names(data))) {
      config$n_col <- NULL
    }

    # INGEN AUTO-DETECTION her - dropdown values respekteres altid
    # Auto-detection sker kun ved data upload i server_column_management.R

    # FIXED: Replace blocking shiny::req() with safe validation
    # If y_col is not available, return NULL instead of hanging with shiny::req()
    if (is.null(config$y_col) || !(config$y_col %in% names(data))) {
      return(NULL)
    }

    return(list(
      x_col = config$x_col,
      y_col = config$y_col,
      n_col = config$n_col,
      chart_type = chart_type
    ))
  })
}
