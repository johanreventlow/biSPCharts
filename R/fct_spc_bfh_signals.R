# fct_spc_bfh_signals.R
# Anhøj Signals & Error Handling
#
# Beregner Anhøj-regler metadata og klassificerer fejl.
# Funktioner:
# - calculate_combined_anhoej_signal() - kombinerer runs + crossings signals
# - classify_error_source() - attribuerer fejl til komponent
# - compute_anhoej_metadata_local() - qicharts2 fallback til UI metrics

calculate_combined_anhoej_signal <- function(
  data,
  runs_col = "runs.signal",
  crossings_col = "crossings.signal"
) {
  safe_operation(
    operation_name = "Anhøj signal calculation",
    code = {
      # Initialize signal to FALSE
      signal <- rep(FALSE, nrow(data))

      # Check for runs signal
      if (runs_col %in% names(data)) {
        runs_signal <- data[[runs_col]]
        if (!is.logical(runs_signal)) {
          runs_signal <- as.logical(runs_signal)
        }
        signal <- signal | runs_signal
      }

      # Check for crossings signal
      # Note: crossings signal is TRUE if n.crossings < n.crossings.min
      if (crossings_col %in% names(data)) {
        crossings_signal <- data[[crossings_col]]
        if (!is.logical(crossings_signal)) {
          crossings_signal <- as.logical(crossings_signal)
        }
        signal <- signal | crossings_signal
      } else if ("n.crossings" %in% names(data) && "n.crossings.min" %in% names(data)) {
        # Calculate crossings signal if component columns exist
        crossings_signal <- data$n.crossings < data$n.crossings.min
        signal <- signal | crossings_signal
      }

      # Handle NAs (set to FALSE)
      signal[is.na(signal)] <- FALSE

      log_debug(
        paste("Calculated combined signal:", sum(signal), "violations"),
        .context = "BFH_SERVICE"
      )

      # NOTE: Don't use return() inside safe_operation code blocks!
      signal
    },
    fallback = rep(FALSE, nrow(data)),
    error_type = "signal_calculation"
  )
}

classify_error_source <- function(error) {
  safe_operation(
    operation_name = "Error source classification",
    code = {
      error_msg <- tolower(conditionMessage(error))

      # BFHcharts-specific errors (highest priority - external dependency)
      if (grepl("bfhcharts::", error_msg, fixed = TRUE) ||
        grepl("bfh_qic", error_msg, fixed = TRUE) ||
        grepl("calculate_limits", error_msg, fixed = TRUE) ||
        grepl("bfhcharts", error_msg, fixed = FALSE)) {
        return(list(
          source = "BFHcharts",
          component = "BFH_INTEGRATION",
          actionable_by = "BFHcharts package maintainer",
          escalate = TRUE,
          user_message = "Fejl i SPC beregning. Kontakt Dataenheden: dataenheden.bispebjerg-frederiksberg-hospitaler@regionh.dk"
        ))
      }

      # biSPCharts integration/validation errors
      if (grepl("missing.*column", error_msg) ||
        grepl("invalid.*type", error_msg) ||
        grepl("validation failed", error_msg) ||
        grepl("required.*parameter", error_msg) ||
        grepl("parameter.*required", error_msg)) {
        return(list(
          source = "biSPCharts",
          component = "BFH_VALIDATION",
          actionable_by = "biSPCharts developer",
          escalate = FALSE,
          user_message = "Konfigurationsfejl. Tjek dine diagramindstillinger."
        ))
      }

      # User data errors (data quality issues)
      if (grepl("empty", error_msg) ||
        grepl("\\bnull\\b", error_msg) ||
        grepl("no.*data", error_msg) ||
        grepl("insufficient.*data", error_msg) ||
        grepl("no valid data", error_msg)) {
        return(list(
          source = "User Data",
          component = "BFH_SERVICE",
          actionable_by = "End user",
          escalate = FALSE,
          user_message = sprintf("Datafejl: %s", conditionMessage(error))
        ))
      }

      # Unknown errors (require investigation)
      return(list(
        source = "Unknown",
        component = "BFH_SERVICE",
        actionable_by = "Developer investigation required",
        escalate = TRUE,
        user_message = "En uventet fejl opstod. Kontakt Dataenheden: dataenheden.bispebjerg-frederiksberg-hospitaler@regionh.dk"
      ))
    },
    fallback = list(
      source = "Unknown",
      component = "BFH_SERVICE",
      actionable_by = "Developer investigation required",
      escalate = TRUE,
      user_message = "En uventet fejl opstod. Kontakt Dataenheden: dataenheden.bispebjerg-frederiksberg-hospitaler@regionh.dk"
    ),
    error_type = "error_classification"
  )
}

compute_anhoej_metadata_local <- function(data, config) {
  safe_operation(
    operation_name = "Anhøj metadata local computation",
    code = {
      # 1. Validate required parameters
      if (is.null(data)) {
        stop("data parameter is required and cannot be NULL")
      }

      if (!is.data.frame(data)) {
        stop("data must be a data.frame")
      }

      if (nrow(data) == 0) {
        stop("data is empty - no data rows to process")
      }

      if (is.null(config)) {
        stop("config parameter is required and cannot be NULL")
      }

      if (!is.list(config)) {
        stop("config must be a list")
      }

      # 2. Validate required config keys
      required_keys <- c("x_col", "y_col", "chart_type")
      missing_keys <- setdiff(required_keys, names(config))

      if (length(missing_keys) > 0) {
        stop(paste(
          "config is missing required keys:",
          paste(missing_keys, collapse = ", ")
        ))
      }


      # Extract config values
      x_col <- config$x_col
      y_col <- config$y_col
      chart_type <- tolower(trimws(config$chart_type)) # Normalize to lowercase
      n_col <- config$n_col # Optional

      # 3. Validate column existence
      if (!x_col %in% names(data)) {
        stop(paste0("x_col '", x_col, "' not found in data columns"))
      }

      if (!y_col %in% names(data)) {
        stop(paste0("y_col '", y_col, "' not found in data columns"))
      }

      if (!is.null(n_col) && !n_col %in% names(data)) {
        stop(paste0("n_col '", n_col, "' not found in data columns"))
      }

      # 4. Check for all NA values in y column
      if (all(is.na(data[[y_col]]))) {
        stop("all values in y_col are NA - no valid data to process")
      }

      # 5. Validate chart type
      if (!chart_type %in% SUPPORTED_CHART_TYPES) {
        stop(paste0(
          "Invalid chart_type: '", chart_type, "'. ",
          "Must be one of: ", paste(SUPPORTED_CHART_TYPES, collapse = ", ")
        ))
      }

      # 6. Additional validation before calling qicharts2
      x_data <- data[[x_col]]
      y_data <- data[[y_col]]
      n_data <- if (!is.null(n_col)) data[[n_col]] else NULL

      # Check vector lengths match
      if (length(x_data) != length(y_data)) {
        stop(paste0(
          "x and y vectors must have same length: ",
          "x=", length(x_data), ", y=", length(y_data)
        ))
      }

      if (!is.null(n_data) && length(y_data) != length(n_data)) {
        stop(paste0(
          "y and n vectors must have same length: ",
          "y=", length(y_data), ", n=", length(n_data)
        ))
      }

      # Check minimum data points
      if (length(y_data) < 3) {
        stop(paste0(
          "Insufficient data points: ", length(y_data),
          ". Minimum 3 points required."
        ))
      }

      # Ensure chart_type is a single scalar string
      if (length(chart_type) != 1 || !is.character(chart_type)) {
        stop(paste0(
          "chart_type must be a single character string, got: ",
          paste(chart_type, collapse = ", ")
        ))
      }

      # 7. Call qicharts2::qic() for Anhøj rules calculation
      # Wrap in tryCatch to provide better error messages
      qic_result <- tryCatch(
        {
          if (!is.null(n_col)) {
            qicharts2::qic(
              x = x_data,
              y = y_data,
              n = n_data,
              chart = chart_type,
              return.data = TRUE
            )
          } else {
            qicharts2::qic(
              x = x_data,
              y = y_data,
              chart = chart_type,
              return.data = TRUE
            )
          }
        },
        error = function(e) {
          stop(paste("qicharts2::qic() failed:", e$message))
        }
      )

      if (is.null(qic_result) || !is.data.frame(qic_result)) {
        stop("qicharts2::qic() did not return valid data frame")
      }

      # 7. Extract Anhøj metadata using existing utility
      metadata <- extract_anhoej_metadata(qic_result)

      if (is.null(metadata)) {
        stop("extract_anhoej_metadata() failed to extract metadata from qic result")
      }

      log_info(
        message = paste(
          "Anhøj metadata computed:",
          "runs_signal =", metadata$runs_signal,
          ", crossings_signal =", metadata$crossings_signal,
          ", longest_run =", metadata$longest_run
        ),
        .context = "BFH_SERVICE"
      )

      return(metadata)
    },
    fallback = NULL,
    show_user = FALSE, # Don't show internal Anhøj calculation errors to user
    error_type = "anhoej_metadata_local"
  )
}
