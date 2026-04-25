# utils_spc_data_processing.R
# Ekstraherede data processing utilities fra fct_spc_plot_generation.R
# Forbedrer modularity og testability

#' Validate SPC plot configuration
#'
#' Validerer input-konfiguration for SPC plot generation.
#' Ekstraeret fra generateSPCPlot for bedre testability.
#'
#' @param config List med konfigurationsvaerdier (x_col, y_col, n_col)
#' @return Sanitized configuration list
#' @keywords internal
sanitize_spc_config <- function(config) {
  safe_operation(
    "SPC config sanitization",
    code = {
      # DEFENSIVE: Check for character(0) in config values
      if (!is.null(config$x_col) && (length(config$x_col) == 0 || identical(config$x_col, character(0)))) {
        config$x_col <- NULL
      }
      if (!is.null(config$y_col) && (length(config$y_col) == 0 || identical(config$y_col, character(0)))) {
        stop("Y-kolonne kan ikke v\u00e6re character(0)")
      }
      if (!is.null(config$n_col) && (length(config$n_col) == 0 || identical(config$n_col, character(0)))) {
        config$n_col <- NULL
      }

      return(config)
    },
    fallback = config,
    error_type = "data_processing"
  )
}

#' Process chart title with reactive handling
#'
#' Processor chart titel med robust reactive vaerdi haandtering.
#' Ekstraeret fra generateSPCPlot for bedre separation of concerns.
#'
# process_chart_title er defineret i fct_spc_helpers.R (med XSS-sanitering)
# Fjernet duplikat uden sanitering (se issue #102)

#' Filter data to complete rows with type preservation
#'
#' Filtrerer data til komplette raekker mens POSIXct/Date formats bevares.
#' Ekstraeret fra generateSPCPlot for genbrug og testability.
#'
#' @param data Original data frame
#' @param y_col Y-column name
#' @param n_col Optional N-column name (for ratio charts)
#' @param x_col Optional X-column name for type preservation
#' @return Filtered data frame with preserved types
#' @keywords internal
filter_complete_spc_data <- function(data, y_col, n_col = NULL, x_col = NULL) {
  safe_operation(
    "SPC data filtering",
    code = {
      if (is.null(n_col)) {
        # Standard numeric data filtering
        y_data_raw <- data[[y_col]]
        complete_rows <- !is.na(y_data_raw) & trimws(as.character(y_data_raw)) != ""

        if (!any(complete_rows)) {
          stop(paste("Ingen gyldige v\u00e6rdier fundet i", y_col, "kolonnen. Tjek at kolonne indeholder numeriske v\u00e6rdier."))
        }
      } else {
        # Ratio chart data filtering
        taeller_raw <- data[[y_col]]
        naevner_raw <- data[[n_col]]

        complete_rows <- !is.na(taeller_raw) & !is.na(naevner_raw) &
          trimws(as.character(taeller_raw)) != "" &
          trimws(as.character(naevner_raw)) != ""

        if (!any(complete_rows)) {
          stop("Ingen komplette datar\u00e6kker fundet. Tjek at b\u00e5de t\u00e6ller og n\u00e6vner kolonner har gyldige v\u00e6rdier.")
        }
      }

      # Store original x-column class for preservation
      original_x_class <- NULL
      if (!is.null(x_col) && x_col %in% names(data)) {
        original_x_class <- class(data[[x_col]])
      }

      # Filter data to complete rows using tidyverse approach
      data_filtered <- data |>
        dplyr::slice(which(complete_rows))

      # PRESERVE POSIXct/Date formats
      if (!is.null(x_col) && x_col %in% names(data) && !is.null(original_x_class)) {
        if (inherits(data[[x_col]], c("POSIXct", "POSIXt", "Date")) &&
          !inherits(data_filtered[[x_col]], c("POSIXct", "POSIXt", "Date"))) {
          # Restore the original class attributes
          data_filtered[[x_col]] <- data[[x_col]][complete_rows]
          class(data_filtered[[x_col]]) <- original_x_class
          attributes(data_filtered[[x_col]]) <- attributes(data[[x_col]])
        }
      }

      return(data_filtered)
    },
    fallback = data,
    error_type = "data_filtering"
  )
}

#' Parse and validate numeric data for SPC charts
#'
#' Parser og validerer numeriske data med dansk locale support.
#' Ekstraeret fra generateSPCPlot for bedre error handling.
#'
#' @param y_data Raw Y-column data
#' @param n_data Optional raw N-column data (for ratio charts)
#' @param y_col Column name for error messages
#' @param n_col Optional N-column name for error messages
#' @return List with parsed y_data and n_data (if provided)
#' @keywords internal
parse_and_validate_spc_data <- function(y_data, n_data = NULL, y_col = "Y", n_col = "N") {
  safe_operation(
    "SPC data parsing and validation",
    code = {
      # Parse Y data
      parsed_y <- parse_danish_number(y_data)

      if (any(is.na(parsed_y))) {
        invalid_count <- sum(is.na(parsed_y))
        stop(paste("Kunne ikke konvertere", invalid_count, "v\u00e6rdier i", y_col, "til numeriske v\u00e6rdier"))
      }

      result <- list(y_data = parsed_y)

      # Parse N data if provided (for ratio charts)
      if (!is.null(n_data)) {
        parsed_n <- parse_danish_number(n_data)

        if (any(is.na(parsed_n))) {
          invalid_count <- sum(is.na(parsed_n))
          stop(paste("Kunne ikke konvertere", invalid_count, "v\u00e6rdier i", n_col, "til numeriske v\u00e6rdier"))
        }

        # Check for zero denominators
        if (any(parsed_n == 0)) {
          stop("N\u00e6vner kan ikke v\u00e6re nul (division by zero)")
        }

        result$n_data <- parsed_n
      }

      return(result)
    },
    fallback = list(y_data = numeric(0), n_data = NULL),
    error_type = "data_parsing"
  )
}

#' Calculate Y-axis data based on chart type
#'
#' Beregner Y-axis data baseret paa chart type og tilgaengelige data.
#' Ekstraeret fra generateSPCPlot for bedre modularity.
#'
#' @param chart_type Chart type ("run", "p", "pp", "u", "up", etc.)
#' @param y_data Parsed Y-column data
#' @param n_data Optional parsed N-column data
#' @return Processed Y-axis data ready for plotting
#' @keywords internal
calculate_y_axis_data <- function(chart_type, y_data, n_data = NULL) {
  safe_operation(
    "Y-axis data calculation",
    code = {
      if (!is.null(n_data)) {
        # Charts with numerator/denominator
        if (chart_type == "run") {
          return(y_data) # Let qic handle ratio calculation for run charts
        } else if (chart_type %in% c("p", "pp", "u", "up")) {
          return(y_data) # Use raw numerator for proportion/rate charts
        } else {
          return((y_data / n_data) * 100) # Default to percentage
        }
      } else {
        # Standard numeric data
        return(y_data)
      }
    },
    fallback = y_data,
    error_type = "y_axis_calculation"
  )
}

#' Generate Y-axis label based on chart type and configuration
#'
#' Genererer Y-axis label baseret paa chart type, enheder og kolonnenavne.
#' Ekstraeret fra generateSPCPlot for consistency og testability.
#'
#' @param chart_type Chart type
#' @param y_unit_label Unit label from configuration
#' @param y_col Y-column name
#' @param n_col Optional N-column name
#' @return Y-axis label string
#' @keywords internal
generate_y_axis_label <- function(chart_type, y_unit_label, y_col, n_col = NULL) {
  safe_operation(
    "Y-axis label generation",
    code = {
      # Use unit label if available and not empty
      if (!is.null(y_unit_label) && nchar(trimws(y_unit_label)) > 0) {
        return(y_unit_label)
      }

      # Generate label based on chart type
      if (!is.null(n_col)) {
        # DEFENSIVE: Check config values before using in paste
        y_col_safe <- if (is.null(y_col) || length(y_col) == 0 || identical(y_col, character(0))) "Y" else y_col
        n_col_safe <- if (is.null(n_col) || length(n_col) == 0 || identical(n_col, character(0))) "N" else n_col

        if (chart_type == "run") {
          return(paste("Rate (", y_col_safe, "/", n_col_safe, ") %"))
        } else if (chart_type %in% c("p", "pp")) {
          return("Proportion")
        } else if (chart_type %in% c("u", "up")) {
          return("Rate")
        } else {
          return(paste("Rate (", y_col_safe, "/", n_col_safe, ") %"))
        }
      } else {
        # Standard single-value charts
        return(y_col %||% "Count")
      }
    },
    fallback = "Count",
    error_type = "label_generation"
  )
}

#' Get unit label with fallback handling
#'
#' Henter unit label fra konfiguration med robust fallback.
#' Helper function til Y-axis label generation.
#'
#' @param y_axis_unit Unit specification
#' @param units_config Units configuration (e.g., Y_AXIS_UNITS_DA)
#' @return Unit label string
#' @keywords internal
get_safe_unit_label <- function(y_axis_unit, units_config = NULL) {
  safe_operation(
    "Unit label retrieval",
    code = {
      # DEFENSIVE: Check for character(0) before calling get_unit_label
      if (length(y_axis_unit) == 0 || identical(y_axis_unit, character(0))) {
        if (exists("get_unit_label", mode = "function") && !is.null(units_config)) {
          return(get_unit_label("count", units_config))
        } else {
          return("")
        }
      } else {
        if (exists("get_unit_label", mode = "function") && !is.null(units_config)) {
          return(get_unit_label(y_axis_unit, units_config))
        } else {
          return(y_axis_unit)
        }
      }
    },
    fallback = "",
    error_type = "unit_label"
  )
}

#' Extract X-axis data with type safety
#'
#' Ekstraherer X-axis data fra data frame med type safety.
#' Helper function for plot generation.
#'
#' @param data Data frame
#' @param x_col X-column name
#' @return X-axis data or NULL if not available
#' @keywords internal
extract_x_axis_data <- function(data, x_col) {
  safe_operation(
    "X-axis data extraction",
    code = {
      if (!is.null(x_col) && x_col %in% names(data)) {
        return(data[[x_col]])
      } else {
        return(NULL)
      }
    },
    fallback = NULL,
    error_type = "x_axis_extraction"
  )
}

# Null coalescing operator is defined in utils_logging.R
