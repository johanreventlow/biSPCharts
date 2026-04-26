# fct_spc_bfh_facade.R
# BFHchart Service Layer Facade
#
# Hovedorkestrator for SPC-beregning via BFHcharts.
# Implementerer adapter-mønstret for at isolere biSPCharts fra BFHcharts API.
#
# Design: Facade-funktion der koordinerer:
# 1. Input validering
# 2. Parameter transformation (via fct_spc_bfh_params)
# 3. BFHcharts invocation (via fct_spc_bfh_invocation)
# 4. Output standardization (via fct_spc_bfh_output)
# 5. Anhøj metadata beregning (via fct_spc_bfh_signals)


#' Compute SPC Results Using BFHchart Backend
#'
#' Primary facade function that wraps BFHchart functionality with biSPCharts conventions.
#' This function provides a stable interface that isolates the application from
#' BFHchart API changes, handles parameter mapping, validates inputs, and standardizes
#' output format for seamless integration with existing biSPCharts plot rendering.
#'
#' @details
#' **Architectural Role:** Service layer facade implementing adapter pattern.
#' Coordinates validation, transformation, BFHchart invocation, and output formatting.
#'
#' **Workflow:**
#' 1. Input validation using existing biSPCharts validators
#' 2. Parameter transformation (biSPCharts conventions → BFHchart API)
#' 3. Safe BFHchart invocation with error handling
#' 4. Output standardization (match qicharts2 format)
#' 5. Structured logging and cache management
#'
#' **Error Handling:** All operations wrapped in `safe_operation()` with graceful
#' fallback. Errors logged with structured context for debugging.
#'
#' @section Notes Column Mapping:
#' The `notes_column` parameter maps to BFHchart's comment/notes system. If BFHchart
#' does not provide native notes support, biSPCharts applies comments as a ggrepel layer
#' after BFHchart rendering (existing pattern). Comment handling includes:
#' - Row ID stability via `.original_row_id` injection
#' - XSS sanitization with Danish character support (æøå)
#' - Intelligent truncation (40 char display, 100 char max)
#' - Collision avoidance with `ggrepel::geom_text_repel()`
#'
#' @param data data.frame. Input dataset with SPC data. Required.
#' @param x_var character. Name of x-axis variable (time/sequence column). Required.
#' @param y_var character. Name of y-axis variable (measure/value column). Required.
#' @param chart_type character. SPC chart type. One of: "run", "i", "mr", "p", "pp",
#'   "u", "up", "c", "g". Required. Use qicharts2-style codes (lowercase).
#' @param n_var character. Name of denominator variable for rate-based charts
#'   (P, P', U, U' charts). Default NULL. Required for charts with denominators.
#' @param cl_var character. Name of control limit override variable. Allows custom
#'   centerline per data point. Default NULL (auto-calculate).
#' @param freeze_var character. Name of freeze period indicator variable. Marks
#'   baseline period for control limit calculation. Default NULL (no freeze).
#' @param part_var character. Name of part/subgroup/phase variable. Enables
#'   per-phase control limit calculation and Anhøj rule application. Default NULL.
#' @param notes_column character. Name of notes/comment column to display on plot.
#'   Maps to BFHchart notes parameter or biSPCharts ggrepel layer. Default NULL.
#' @param multiply numeric. Multiplier applied to y-axis values for display scaling.
#'   Common use: convert decimal proportions to percentages (multiply = 100).
#'   Default 1 (no scaling).
#' @param use_cache logical. Enable caching for SPC computation results. Default TRUE.
#'   Set to FALSE to force fresh computation (useful for debugging or testing).
#' @param app_state Application state object. Required for cache access. If NULL,
#'   caching is disabled. Default NULL.
#' @param ... Additional arguments passed to BFHchart backend. Allows flexibility
#'   for BFHchart-specific parameters without breaking biSPCharts interface.
#'
#' @return list with three components:
#'   \describe{
#'     \item{plot}{ggplot2 object. Rendered SPC chart with control limits, centerline,
#'       and optional annotations. Compatible with biSPCharts plot customization functions.}
#'     \item{qic_data}{tibble. Standardized data frame with SPC calculations. Columns:
#'       \itemize{
#'         \item x: X-axis values (dates or observation numbers)
#'         \item y: Y-axis values (original or scaled measures)
#'         \item cl: Centerline per data point (may vary by phase)
#'         \item ucl: Upper control limit per data point
#'         \item lcl: Lower control limit per data point
#'         \item part: Phase/subgroup indicator (integer, starting at 1)
#'         \item signal: Combined Anhøj signal (logical, TRUE if runs OR crossings violation)
#'         \item .original_row_id: Row identifier for stable comment mapping
#'       }
#'     }
#'     \item{metadata}{list. Chart configuration and diagnostic information:
#'       \itemize{
#'         \item chart_type: Chart type used
#'         \item n_points: Number of data points processed
#'         \item n_phases: Number of phases (if part_var specified)
#'         \item freeze_applied: Logical indicating if freeze was applied
#'         \item signals_detected: Count of Anhøj rule violations
#'         \item bfh_version: BFHchart package version used
#'         \item anhoej_rules: list with Anhøj rules metadata (runs_detected, crossings_detected, longest_run, n_crossings, n_crossings_min)
#'       }
#'     }
#'   }
#'   Returns NULL on error (with structured logging).
#' @examples
#' \dontrun{
#' # Basic run chart
#' result <- compute_spc_results_bfh(
#'   data = hospital_data,
#'   x_var = "month",
#'   y_var = "infections",
#'   chart_type = "run"
#' )
#' print(result$plot)
#' summary(result$qic_data)
#'
#' # P-chart with denominator and freeze period
#' result <- compute_spc_results_bfh(
#'   data = surgical_data,
#'   x_var = "date",
#'   y_var = "complications",
#'   n_var = "procedures",
#'   chart_type = "p",
#'   freeze_var = "baseline_indicator",
#'   multiply = 100
#' )
#'
#' # Multi-phase I-chart with comments
#' result <- compute_spc_results_bfh(
#'   data = quality_data,
#'   x_var = "week",
#'   y_var = "defects",
#'   chart_type = "i",
#'   part_var = "intervention_phase",
#'   notes_column = "comment",
#'   multiply = 1
#' )
#'
#' # Access standardized data
#' print(result$qic_data)
#' # Check metadata
#' print(result$metadata$signals_detected)
#' }
#'
#' @seealso
#' \code{map_to_bfh_params} for parameter transformation logic
#' \code{transform_bfh_output} for output standardization
#' @export
compute_spc_results_bfh <- function(
  data,
  x_var,
  y_var,
  chart_type,
  n_var = NULL,
  cl_var = NULL,
  freeze_var = NULL,
  part_var = NULL,
  notes_column = NULL,
  multiply = 1,
  use_cache = TRUE,
  app_state = NULL,
  ...
) {
  req <- validate_spc_request(
    data = if (missing(data)) NULL else data,
    x_var = if (missing(x_var)) NULL else x_var,
    y_var = if (missing(y_var)) NULL else y_var,
    chart_type = if (missing(chart_type)) NULL else chart_type,
    n_var = n_var,
    cl_var = cl_var,
    freeze_var = freeze_var,
    part_var = part_var,
    notes_column = notes_column,
    multiply = multiply,
    ...
  )

  extra_params <- list(...)
  cache_key <- build_cache_key(data, chart_type, x_var, y_var, n_var, multiply, extra_params, use_cache)

  cached <- read_spc_cache(cache_key, app_state)
  if (!is.null(cached)) {
    return(cached)
  }

  prepared <- prepare_spc_data(req)
  axes <- resolve_axis_units(prepared)
  bfh_params <- build_bfh_args(prepared, axes, extra_params)
  standardized <- execute_bfh_request(bfh_params, prepared)
  standardized <- decorate_plot_for_display(standardized, prepared)

  write_spc_cache(cache_key, standardized, app_state)

  log_info(
    message = "SPC computation completed successfully",
    .context = "BFH_SERVICE",
    details = list(
      chart_type = req$chart_type,
      n_points = nrow(standardized$qic_data),
      signals_detected = sum(standardized$qic_data$signal, na.rm = TRUE),
      has_notes = !is.null(notes_column),
      cached = !is.null(cache_key)
    )
  )

  standardized
}


#' Byg cache-nøgle for SPC-beregning
#'
#' @keywords internal
build_cache_key <- function(data, chart_type, x_var, y_var, n_var, multiply, extra_params, use_cache) {
  if (!use_cache) {
    return(NULL)
  }
  tryCatch(
    {
      cache_config <- list(
        chart_type = chart_type,
        x_column = x_var,
        y_column = y_var,
        n_column = n_var,
        freeze_position = NULL,
        part_positions = NULL,
        target_value = extra_params$target_value,
        centerline_value = extra_params$centerline_value,
        y_axis_unit = extra_params$y_axis_unit,
        multiply_by = multiply,
        # Viewport dimensions inkluderes: ellers ville plots fra export (andre dims)
        # fejlagtigt genbruges fra analysis-cache eller omvendt.
        viewport_width = extra_params$width,
        viewport_height = extra_params$height
      )
      generate_spc_cache_key(data, cache_config)
    },
    error = function(e) {
      log_warn(paste("Cache key generation failed:", e$message), .context = "BFH_SERVICE")
      NULL
    }
  )
}


#' Læs cachet SPC-resultat
#'
#' @keywords internal
read_spc_cache <- function(cache_key, app_state) {
  if (is.null(cache_key) || is.null(app_state)) {
    return(NULL)
  }
  tryCatch(
    {
      qic_cache <- get_or_init_qic_cache(app_state)
      if (is.null(qic_cache)) {
        return(NULL)
      }
      result <- get_cached_spc_result(cache_key, qic_cache)
      if (!is.null(result)) {
        log_info(paste("Cache hit:", substr(cache_key, 1, 40), "..."), .context = "BFH_SERVICE")
      } else {
        log_debug(paste("Cache miss:", substr(cache_key, 1, 40), "..."), .context = "BFH_SERVICE")
      }
      result
    },
    error = function(e) {
      log_warn(paste("Cache retrieval failed:", e$message), .context = "BFH_SERVICE")
      NULL
    }
  )
}


#' Gem SPC-resultat i cache
#'
#' @keywords internal
write_spc_cache <- function(cache_key, result, app_state) {
  if (is.null(cache_key) || is.null(app_state)) {
    return(invisible(NULL))
  }
  tryCatch(
    {
      qic_cache <- get_or_init_qic_cache(app_state)
      if (!is.null(qic_cache)) {
        cache_ttl <- CACHE_CONFIG$default_timeout_seconds %||% 3600
        cache_spc_result(cache_key, result, qic_cache, ttl = cache_ttl)
        log_debug(paste("Result cached with TTL:", cache_ttl, "seconds"), .context = "BFH_SERVICE")
      }
    },
    error = function(e) {
      log_warn(paste("Cache storage failed:", e$message), .context = "BFH_SERVICE")
    }
  )
  invisible(NULL)
}


#' Resolve BFHchart Chart Title
#'
#' Helper for resolving reactive or static chart titles. Handles reactiveValues
#' that may be NULL or contain title strings. Internal utility.
#'
#' @param title_candidate Reactive or character. Title value (may be reactive).
#'
#' @return character. Resolved title or NULL.
#'
#' @keywords internal
resolve_bfh_chart_title <- function(title_candidate) {
  safe_operation(
    operation_name = "BFHchart chart title resolution",
    code = {
      # NOTE: Don't use return() inside safe_operation code blocks!
      # Use conditional flow with result variable instead

      # Handle NULL input
      if (is.null(title_candidate)) {
        result <- NULL
      }
      # Handle empty string
      else if (identical(title_candidate, "")) {
        result <- NULL
      }
      # Handle reactive (shiny reactive value)
      else if (is.reactive(title_candidate)) {
        # Try to evaluate reactive if callable
        tryCatch(
          {
            value <- title_candidate()
            if (is.null(value) || identical(value, "")) {
              result <- NULL
            } else {
              result <- as.character(value)
            }
          },
          error = function(e) {
            result <<- NULL
          }
        )
      }
      # Handle character or numeric (convert to string)
      else {
        result <- as.character(title_candidate)
        # Final check for empty result
        if (identical(result, "")) {
          result <- NULL
        }
      }

      result
    },
    fallback = NULL,
    error_type = "title_resolution"
  )
}
