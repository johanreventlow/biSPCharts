# fct_spc_bfh_invocation.R
# BFHchart Safe Invocation Layer
#
# Sikker indkapsling af BFHcharts API-kald med:
# - Inputvalidering (chart_type, parameter struktur)
# - Error handling og graceful degradation
# - Diagnostisk logging

call_bfh_chart <- function(bfh_params) {
  safe_operation(
    operation_name = "BFHchart API call",
    code = {
      # 1. Validate params structure
      if (is.null(bfh_params) || !is.list(bfh_params)) {
        stop("bfh_params must be a non-null list")
      }

      required_keys <- c("data", "x", "y", "chart_type")
      missing_keys <- setdiff(required_keys, names(bfh_params))
      if (length(missing_keys) > 0) {
        stop(paste(
          "Missing required parameters:",
          paste(missing_keys, collapse = ", ")
        ))
      }

      # 2. Log invocation
      log_debug(
        paste(
          "Calling BFHcharts::bfh_qic with",
          nrow(bfh_params$data), "rows"
        ),
        .context = "BFH_SERVICE"
      )

      # 3. Measure execution time
      start_time <- Sys.time()

      # 3b. CONSERVATIVE APPROACH: Only send core params
      # BFHcharts accepterer kun et subset af parametre.
      # plot_context sendes IKKE — BFHcharts bruger kun dimensioner i inches.
      fields_to_keep <- c("data", "x", "y", "n", "chart_type", "freeze", "part", "multiply", "target_value", "target_text", "cl", "notes", "y_axis_unit", "width", "height", "units", "base_size", "chart_title")
      bfh_params_clean <- bfh_params[names(bfh_params) %in% fields_to_keep]

      removed_fields <- setdiff(names(bfh_params), fields_to_keep)
      log_debug(
        paste(
          "Conservative param filtering - removed:",
          paste(removed_fields, collapse = ", ")
        ),
        .context = "BFH_SERVICE"
      )

      # Log target_value if present
      if ("target_value" %in% names(bfh_params_clean)) {
        log_debug(
          paste(
            "Target parameter included: target_value =", bfh_params_clean$target_value
          ),
          .context = "BFH_SERVICE"
        )
      }

      # Log cl (centerline) if present
      if ("cl" %in% names(bfh_params_clean)) {
        log_debug(
          paste(
            "Centerline parameter included: cl =", bfh_params_clean$cl
          ),
          .context = "BFH_SERVICE"
        )
      }

      # Log y_axis_unit if present
      if ("y_axis_unit" %in% names(bfh_params_clean)) {
        log_debug(
          paste(
            "Y-axis unit parameter included: y_axis_unit =", bfh_params_clean$y_axis_unit
          ),
          .context = "BFH_SERVICE"
        )
      }

      # Log notes parameter presence
      log_debug(
        paste(
          "[NOTES_TRACE] Is 'notes' param passed to BFHcharts?:",
          "notes" %in% names(bfh_params_clean),
          "| Notes count:", if ("notes" %in% names(bfh_params_clean)) length(bfh_params_clean$notes) else 0
        ),
        .context = "BFH_SERVICE"
      )

      # 3c. DEBUG: Log data types being sent to BFHcharts
      if (!is.null(bfh_params_clean$data)) {
        x_col_name <- as.character(bfh_params_clean$x)
        y_col_name <- as.character(bfh_params_clean$y)
        n_col_name <- if (!is.null(bfh_params_clean$n)) as.character(bfh_params_clean$n) else NULL

        log_debug(
          paste(
            "BFHcharts data types:",
            "x(", x_col_name, ")=", class(bfh_params_clean$data[[x_col_name]])[1],
            ", y(", y_col_name, ")=", class(bfh_params_clean$data[[y_col_name]])[1],
            if (!is.null(n_col_name)) paste0(", n(", n_col_name, ")=", class(bfh_params_clean$data[[n_col_name]])[1]) else ""
          ),
          .context = "BFH_SERVICE"
        )
      }

      # 4. Call BFHchart (use bfh_qic high-level API)
      # Returns bfh_qic_result S3 object with plot, qic_data, summary, config
      result <- do.call(BFHcharts::bfh_qic, bfh_params_clean)

      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

      # 5. Log success with timing
      log_info(
        paste("BFHchart bfh_qic() call:", round(elapsed, 3), "seconds"),
        .context = "BFH_SERVICE"
      )
      log_debug(
        paste(
          "[DEBUG] bfh_qic result - class:",
          paste(class(result), collapse = ", "),
          "| names:", paste(names(result), collapse = ", "),
          "| is_bfh_qic_result:", BFHcharts::is_bfh_qic_result(result)
        ),
        .context = "BFH_SERVICE"
      )

      # NOTE: Don't use return() inside safe_operation code blocks!
      result
    },
    fallback = NULL,
    show_user = TRUE,
    error_type = "bfh_api_call"
  )
}


#' Transform BFHchart Output to Standardized Format
#'
#' Converts BFHchart output (ggplot object) to biSPCharts's standardized
#' format matching qicharts2 structure. Ensures output compatibility with
#' existing biSPCharts plot rendering, customization, and export functions.
#'
#' @details
#' **Transformation Responsibilities:**
#' - Extract qic_data from ggplot object layers
#' - Standardize column names (BFHchart → biSPCharts conventions)
#' - Apply multiply scaling to y-axis values
#' - Calculate combined Anhøj signal if not provided by BFHchart
#' - Ensure required columns present: x, y, cl, ucl, lcl, part, signal
#' - Preserve `.original_row_id` for comment mapping
#' - Build metadata list with diagnostic information
#'
#' **Output Structure (qicharts2-compatible):**
#' - `qic_data` tibble with standardized columns
#' - `plot` ggplot2 object
#' - `metadata` list with configuration and diagnostics
#'
#' **Anhøj Signal Calculation:**
#' If BFHchart does not provide combined signal, calculate as:
#' `signal <- runs.signal | crossings.signal`
#' Applied per-phase if part column present.
#'
#' @param bfh_result ggplot2 object from BFHchart.
#' @param multiply numeric. Multiplier to apply to y-axis values. Default 1.
#'   Common use: 100 for percentage display.
#' @param chart_type character. Chart type for metadata. Used in diagnostic logging.
#' @param original_data data.frame. Original input data for comment mapping and
#'   row count validation. Optional but recommended.
#' @param freeze_applied logical. Whether freeze was applied in parameter mapping.
#'   Default FALSE. Used to set metadata correctly since BFHcharts doesn't return
#'   a freeze column.
#'
#' @return list with three components:
#'   \describe{
#'     \item{plot}{ggplot2 object compatible with biSPCharts customization}
#'     \item{qic_data}{tibble with standardized SPC data (qicharts2 format)}
#'     \item{metadata}{list with chart configuration and diagnostics}
#'   }
#'   Returns NULL on transformation failure (with error logging).
#' @examples
#' \dontrun{
#' # Transform BFHchart plot output
#' bfh_result <- call_bfh_chart(bfh_params)
#' standardized <- transform_bfh_output(
#'   bfh_result = bfh_result,
#'   multiply = 100,
#'   chart_type = "p",
#'   original_data = clean_data
#' )
#'
#' # Access standardized components
#' print(standardized$plot)
#' summary(standardized$qic_data)
#' print(standardized$metadata$signals_detected)
#'
#' # Use with existing biSPCharts functions
#' customized_plot <- apply_hospital_theme(standardized$plot)
#' export_plot(customized_plot, filename = "spc_chart.png")
#' }
#'
#' @seealso
#' \code{\link{compute_spc_results_bfh}} for facade interface
#' \code{\link{call_bfh_chart}} for BFHchart invocation
#' @keywords internal

validate_chart_type_bfh <- function(chart_type) {
  safe_operation(
    operation_name = "Chart type validation",
    code = {
      # Supported chart types (fra config_chart_types.R)
      supported_types <- SUPPORTED_CHART_TYPES_BFH

      # Normalize to lowercase
      chart_type <- tolower(trimws(chart_type))

      # Validate
      if (!chart_type %in% supported_types) {
        stop(paste0(
          "Invalid chart_type: '", chart_type, "'. ",
          "Must be one of: ", paste(supported_types, collapse = ", ")
        ))
      }

      log_debug(paste("Chart type validated:", chart_type), .context = "BFH_SERVICE")

      # NOTE: Don't use return() inside safe_operation code blocks!
      chart_type
    },
    fallback = NULL,
    error_type = "chart_type_validation"
  )
}


#' Calculate Combined Anhøj Signal
#'
#' Computes combined Anhøj rule signal from runs and crossings data.
#' Internal helper for output standardization when BFHchart doesn't provide
#' combined signal.
#'
#' @param data data.frame. Data with runs and crossings columns.
#' @param runs_col character. Name of runs signal column. Default "runs.signal".
#' @param crossings_col character. Name of crossings signal column. Default "crossings.signal".
#'
#' @return logical vector. Combined signal (TRUE if runs OR crossings violation).
#'
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' signal <- calculate_combined_anhoej_signal(
#'   data = bfh_data,
#'   runs_col = "runs",
#'   crossings_col = "crossings"
#' )
#' bfh_data$signal <- signal
#' }
