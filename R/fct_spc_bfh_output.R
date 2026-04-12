# fct_spc_bfh_output.R
# BFHchart Output Processing & Comment Integration
#
# Transformerer BFHcharts-output til standardiseret format.
# Håndterer:
# - Output-strukturering (plot, qic_data, metadata)
# - Anhøj-rules-ekstrahering
# - Comment-annotation (note-placering med ggrepel)

transform_bfh_output <- function(
  bfh_result,
  multiply = 1,
  chart_type = NULL,
  original_data = NULL,
  freeze_applied = FALSE
) {
  safe_operation(
    operation_name = "BFHchart output transformation",
    code = {
      # DEBUG: Log input type before validation
      log_debug(
        paste(
          "[DEBUG] transform_bfh_output input - class:",
          paste(class(bfh_result), collapse = ", "),
          "| is.null:", is.null(bfh_result),
          "| is.list:", is.list(bfh_result),
          "| names:", if (is.list(bfh_result)) paste(names(bfh_result), collapse = ", ") else "N/A"
        ),
        .context = "BFH_SERVICE"
      )

      # 1. Validate input - bfh_qic() returns bfh_qic_result S3 object
      # Use robust check: either S3 class or duck-typing for list with required fields
      is_valid <- BFHcharts::is_bfh_qic_result(bfh_result) ||
        (is.list(bfh_result) && all(c("plot", "qic_data") %in% names(bfh_result)))

      log_debug(
        paste("[DEBUG] Validation result:", is_valid),
        .context = "BFH_SERVICE"
      )

      if (!is_valid) {
        stop("bfh_result must be a bfh_qic_result object from BFHcharts::bfh_qic()")
      }

      # 2. Extract components from bfh_qic_result object
      # Structure: list(plot = ggplot, qic_data = tibble, summary = list, config = list)
      # Use get_plot() for S3 objects, direct access for plain lists
      plot_object <- if (BFHcharts::is_bfh_qic_result(bfh_result)) {
        BFHcharts::get_plot(bfh_result)
      } else {
        bfh_result$plot
      }
      qic_data <- bfh_result$qic_data

      log_debug(
        paste(
          "[DEBUG] Extracted - plot_object class:",
          paste(class(plot_object), collapse = ", "),
          "| qic_data rows:", if (!is.null(qic_data)) nrow(qic_data) else "NULL"
        ),
        .context = "BFH_SERVICE"
      )

      if (is.null(qic_data) || nrow(qic_data) == 0) {
        stop("Could not extract qic_data from BFHcharts result")
      }

      # 4. Standardize column names to match qicharts2 format
      # Required columns: x, y, cl, ucl, lcl, signal
      required_cols <- c("x", "y", "cl")

      # Check if required columns exist
      missing_cols <- setdiff(required_cols, names(qic_data))
      if (length(missing_cols) > 0) {
        stop(paste(
          "Missing required columns in qic_data:",
          paste(missing_cols, collapse = ", ")
        ))
      }

      # 5. Apply multiply to y-axis values
      if (multiply != 1) {
        qic_data$y <- qic_data$y * multiply
        qic_data$cl <- qic_data$cl * multiply
        if ("ucl" %in% names(qic_data)) {
          qic_data$ucl <- qic_data$ucl * multiply
        }
        if ("lcl" %in% names(qic_data)) {
          qic_data$lcl <- qic_data$lcl * multiply
        }
      }

      # 6. Ensure ucl/lcl columns exist (may be NA for run charts)
      if (!"ucl" %in% names(qic_data)) {
        qic_data$ucl <- NA_real_
      }
      if (!"lcl" %in% names(qic_data)) {
        qic_data$lcl <- NA_real_
      }

      # 7. Extract Anhøj rules metadata from BFHchart output
      anhoej_metadata <- extract_anhoej_metadata(qic_data)

      # 8. Use BFHchart's anhoej.signal or calculate combined signal
      if ("anhoej.signal" %in% names(qic_data)) {
        qic_data$signal <- qic_data$anhoej.signal
      } else if (!is.null(anhoej_metadata)) {
        qic_data$signal <- anhoej_metadata$signal_points
      } else {
        # Fallback: calculate from components
        qic_data$signal <- calculate_combined_anhoej_signal(qic_data)
      }

      # 9. Ensure part column exists
      if (!"part" %in% names(qic_data)) {
        qic_data$part <- factor(rep(1, nrow(qic_data)))
      }

      # 10. Convert to tibble for consistency
      qic_data <- tibble::as_tibble(qic_data)

      # 11. Build metadata with Anhøj rules
      metadata <- list(
        chart_type = chart_type,
        n_points = nrow(qic_data),
        n_phases = length(unique(qic_data$part)),
        freeze_applied = freeze_applied, # Use parameter passed from compute_spc_results_bfh
        signals_detected = if ("signal" %in% names(qic_data) && "part" %in% names(qic_data)) {
          # Tæl antal parts med signal (anhoej.signal er per-part, ikke per-punkt)
          sum(tapply(qic_data$signal, qic_data$part, function(x) any(x, na.rm = TRUE)))
        } else {
          sum(qic_data$signal, na.rm = TRUE)
        },
        bfh_version = as.character(utils::packageVersion("BFHcharts")),
        anhoej_rules = if (!is.null(anhoej_metadata)) {
          list(
            runs_detected = anhoej_metadata$runs_signal,
            crossings_detected = anhoej_metadata$crossings_signal,
            longest_run = anhoej_metadata$longest_run,
            n_crossings = anhoej_metadata$n_crossings,
            n_crossings_min = anhoej_metadata$n_crossings_min
          )
        } else {
          NULL
        }
      )

      log_debug(
        paste(
          "Output transformed:",
          metadata$n_points, "points,",
          metadata$signals_detected, "signals detected"
        ),
        .context = "BFH_SERVICE"
      )

      # Log Anhøj metadata if available
      if (!is.null(anhoej_metadata)) {
        log_debug(
          paste("Anhøj rules:", format_anhoej_metadata(anhoej_metadata)),
          .context = "BFH_SERVICE"
        )
      }

      # 11. Return standardized structure with bfh_qic_result for exports
      # NOTE: Don't use return() inside safe_operation code blocks!
      list(
        plot = plot_object,
        qic_data = qic_data,
        metadata = metadata,
        bfh_qic_result = bfh_result # Full result for BFHcharts export functions
      )
    },
    fallback = NULL,
    error_type = "output_transformation"
  )
}


#' Validate Chart Type for BFHchart Compatibility
#'
#' Validates that chart type is supported by BFHchart and maps qicharts2 codes
#' to BFHchart equivalents if necessary. Internal helper for parameter validation.
#'
#' @param chart_type character. Chart type code (qicharts2 style).
#'
#' @return character. Validated and potentially mapped chart type for BFHchart.
#'   Throws error if chart type not supported.
#'
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' validate_chart_type_bfh("run") # Returns "run"
#' validate_chart_type_bfh("i") # Returns "i"
#' validate_chart_type_bfh("pp") # Returns "pp" (if supported) or throws error
#' validate_chart_type_bfh("invalid") # Throws error
#' }
