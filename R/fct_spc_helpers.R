# fct_spc_helpers.R
# SPC helper functions: date formatting, validation, preprocessing
# Extracted from fct_spc_calculations.R for better maintainability

# Dependencies ----------------------------------------------------------------

# HJÆLPEFUNKTIONER ============================================================

#' Tjek om en kolonne primært indeholder numeriske værdier
#'
#' @param col Vector. Kolonne at tjekke.
#' @param threshold Numeric. Andel non-NA værdier der skal være numeriske (0-1).
#' @return Logical. TRUE hvis kolonnen er numerisk nok.
#' @keywords internal
is_column_numeric <- function(col, threshold = 0.5) {
  if (is.numeric(col)) return(TRUE)
  non_na <- col[!is.na(col)]
  if (length(non_na) == 0) return(TRUE)
  parsed <- suppressWarnings(as.numeric(as.character(non_na)))
  sum(!is.na(parsed)) / length(non_na) >= threshold
}

#' Bestem value box theme baseret på signal-status
#'
#' Bruger dark/light for at signalere udfald uden at antyde fejl/succes.
#'
#' @param status_info List med status felt.
#' @param signal Logical. TRUE hvis signal er detekteret.
#' @return Character. bslib theme navn.
#' @keywords internal
value_box_signal_theme <- function(status_info, signal) {
  if (status_info$status == "ready" && isTRUE(signal)) {
    "dark"
  } else if (status_info$status == "ready") {
    "light"
  } else {
    status_info$theme
  }
}

#' Konverter enheds-kode til dansk label
#'
#' @param unit_code Character. Kode for organisatorisk enhed
#' @param unit_list Named list. Mapping mellem enheder og koder
#' @return Character. Dansk label for enheden
#' @family spc_helpers
#' @keywords internal
get_unit_label <- function(unit_code, unit_list) {
  if (is.null(unit_code) || unit_code == "") {
    return("")
  }

  # Find dansk navn baseret på værdi
  unit_names <- names(unit_list)[unit_list == unit_code]
  if (length(unit_names) > 0) {
    return(unit_names[1])
  }

  # Fallback til koden selv
  return(unit_code)
}

#' Valider og formater X-akse data til SPC charts
#'
#' Intelligent validering og formatering af X-akse data, med automatisk
#' detektion af dato formater og optimeret visning baseret på data interval.
#'
#' @param x_data Vector. Rå X-akse data (datoer, tal eller tekst)
#' @return List med formateret data og metadata
#' @details
#' Validering proces:
#' \enumerate{
#'   \item Tjek om x_col eksisterer i data
#'   \item Forsøg dato parsing for forskellige formater
#'   \item Beregn optimal date interval hvis dato
#'   \item Generer formaterings string for qicharts2
#'   \item Fallback til numerisk sekvensnummerering
#' }
#'
#' Understøttede dato formater:
#' \itemize{
#'   \item "dd-mm-yyyy" (dansk standard)
#'   \item "yyyy-mm-dd" (ISO)
#'   \item "mm/dd/yyyy" (amerikansk)
#'   \item Automatisk locale detection
#' }
#'
#' @return List med formateret X-akse data:
#' \describe{
#'   \item{x_data}{Formateret X-akse værdier}
#'   \item{x.format}{qicharts2 formaterings string eller NULL}
#'   \item{is_date}{Logical - om data er datoer}
#'   \item{interval_info}{Liste med interval statistik (kun datoer)}
#' }
#'
#' @examples
#' \dontrun{
#' # Dato data
#' data <- data.frame(
#'   Dato = c("01-01-2024", "01-02-2024", "01-03-2024"),
#'   Værdi = c(95, 92, 98)
#' )
#' result <- validate_x_column_format(data, "Dato", "day")
#'
#' # Numerisk data
#' data_num <- data.frame(Obs = 1:10, Værdi = rnorm(10))
#' result <- validate_x_column_format(data_num, "Obs", "observation")
#' }
#'
validate_x_column_format <- function(data, x_col, x_axis_unit = "observation") {
  # Return default hvis ingen x-kolonne
  if (is.null(x_col) || !x_col %in% names(data)) {
    return(list(
      x_data = 1:nrow(data),
      x.format = NULL,
      is_date = FALSE
    ))
  }

  x_data <- data[[x_col]]

  # Tjek om data allerede er Date/POSIXct
  if (inherits(x_data, c("Date", "POSIXct", "POSIXt"))) {
    # Data er allerede formateret som dato/tid
    x_format <- get_x_format_string(x_axis_unit)
    return(list(
      x_data = x_data,
      x.format = x_format,
      is_date = TRUE
    ))
  }

  # Forsøg intelligent date detection med lubridate
  if (is.character(x_data) || is.factor(x_data)) {
    char_data <- as.character(x_data)[!is.na(x_data)]

    if (length(char_data) > 0) {
      # Test sample til date detection
      test_sample <- char_data[1:min(5, length(char_data))]

      # FØRST: Test danske dato-formater direkte (mest almindelige)
      danish_parsed <- suppressWarnings(lubridate::dmy(char_data))
      danish_success_rate <- sum(!is.na(danish_parsed)) / length(danish_parsed)

      if (danish_success_rate >= 0.7) {
        # Danske datoer fungerer - konverter til POSIXct for konsistens med qicharts2
        x_data_converted <- as.POSIXct(danish_parsed)
        x_format <- get_x_format_string(x_axis_unit)


        return(list(
          x_data = x_data_converted,
          x.format = x_format,
          is_date = TRUE
        ))
      }

      # FALLBACK: Brug lubridate guess_formats for andre formater (med error handling)
      safe_operation(
        "Parse dates using lubridate guess_formats",
        code = {
          guessed_formats <- suppressWarnings(
            lubridate::guess_formats(test_sample, c("ymd", "dmy", "mdy", "dby", "dmY", "Ymd", "mdY"))
          )

          if (!is.null(guessed_formats) && length(guessed_formats) > 0) {
            # Filtrer ugyldige formater (undgå "n" format problem)
            valid_formats <- guessed_formats[!grepl("^n$|Unknown", guessed_formats)]

            if (length(valid_formats) > 0) {
              # Test konvertering med guessed formats
              parsed_dates <- suppressWarnings(
                lubridate::parse_date_time(char_data, orders = valid_formats, quiet = TRUE)
              )

              if (!is.null(parsed_dates)) {
                success_rate <- sum(!is.na(parsed_dates)) / length(parsed_dates)

                if (success_rate >= 0.7) { # 70% success rate threshold
                  # Konverter til Date objekter
                  x_data_converted <- as.Date(parsed_dates)
                  x_format <- get_x_format_string(x_axis_unit)

                  return(list(
                    x_data = x_data_converted,
                    x.format = x_format,
                    is_date = TRUE
                  ))
                }
              }
            }
          }
        },
        fallback = function(e) {
          # Skip denne parsing metode hvis den fejler
        },
        error_type = "processing"
      )
    }
  }

  # Numerisk data eller tekst der ikke kunne parses som datoer
  if (is.numeric(x_data)) {
    return(list(
      x_data = x_data,
      x.format = NULL,
      is_date = FALSE
    ))
  } else {
    # Fallback til observation nummer
    return(list(
      x_data = 1:length(x_data),
      x.format = NULL,
      is_date = FALSE
    ))
  }
}

## Simpel formatering baseret på x_axis_unit
get_x_format_string <- function(x_axis_unit) {
  switch(x_axis_unit,
    "date" = "%Y-%m-%d",
    "month" = "%b %Y",
    "year" = "%Y",
    "week" = "Uge %W",
    "hour" = "%H:%M",
    "%Y-%m-%d" # default
  )
}

# SPC PLOT GENERERING =========================================================

#' Process chart title for SPC plot
#'
#' @param chart_title_reactive Reactive function for chart title
#' @param config Chart configuration with y_col
#' @return Character string with processed title
process_chart_title <- function(chart_title_reactive, config) {
  custom_title <- safe_operation(
    "Process chart title reactive",
    code = {
      if (!is.null(chart_title_reactive) && is.function(chart_title_reactive)) {
        title <- chart_title_reactive()
        if (!is.null(title) && title != "" && title != "SPC Analyse") {
          title
        } else {
          NULL
        }
      } else {
        NULL
      }
    },
    fallback = function(e) {
      log_error(paste("ERROR in chart_title_reactive:", e$message), "SPC_CALC_DEBUG")
      NULL
    },
    error_type = "processing"
  )


  # SPRINT 3: Sanitize title for XSS protection
  title_result <- if (!is.null(custom_title)) {
    custom_title
  } else {
    paste("SPC Diagram -", config$y_col)
  }

  # Sanitize titel mod XSS
  title_result <- sanitize_user_input(
    input_value = title_result,
    max_length = 200,
    allowed_chars = "A-Za-z0-9_æøåÆØÅ .,-:!?/",
    html_escape = TRUE
  )

  return(title_result)
}

# CHART VALIDATION ============================================================

## Validering af Data til Chart Generering
# Tjekker data kvalitet og kompatibilitet med valgt chart type
validateDataForChart <- function(data, config, chart_type) {
  warnings <- character(0)

  # DEBUG: Log validation inputs
  log_debug_kv(
    message = "VALIDATION INPUTS",
    chart_type = chart_type %||% "NULL",
    has_data = !is.null(data),
    data_rows = if (!is.null(data)) nrow(data) else 0,
    y_col = config$y_col %||% "NULL",
    n_col = config$n_col %||% "NULL",
    .context = "[DEBUG_VALIDATION]"
  )

  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) {
    warnings <- c(warnings, "Ingen data tilgængelig")
    log_debug_kv(
      message = "VALIDATION FAILED: No data",
      .context = "[DEBUG_VALIDATION]"
    )
    return(list(valid = FALSE, warnings = warnings))
  }

  if (is.null(config$y_col) || !config$y_col %in% names(data)) {
    warnings <- c(warnings, "Ingen numerisk kolonne fundet til Y-akse")
    log_debug_kv(
      message = "VALIDATION FAILED: No y_col",
      y_col = config$y_col %||% "NULL",
      .context = "[DEBUG_VALIDATION]"
    )
    return(list(valid = FALSE, warnings = warnings))
  }

  if (chart_type %in% c("p", "pp", "u", "up")) {
    if (is.null(config$n_col) || !config$n_col %in% names(data)) {
      warnings <- c(warnings, paste("Chart type", chart_type, "kræver en nævner-kolonne"))
      log_debug_kv(
        message = "VALIDATION FAILED: Chart type requires denominator",
        chart_type = chart_type,
        n_col = config$n_col %||% "NULL",
        .context = "[DEBUG_VALIDATION]"
      )
      return(list(valid = FALSE, warnings = warnings))
    }
  }

  # Check for missing values
  y_data <- data[[config$y_col]]
  if (all(is.na(y_data))) {
    warnings <- c(warnings, "Alle værdier i Y-kolonnen er tomme")
    return(list(valid = FALSE, warnings = warnings))
  }

  # Skift column validation handled by qicharts2::qic() internally

  if (nrow(data) < 8) {
    warnings <- c(warnings, paste("Kun", nrow(data), "datapunkter - SPC analyse er mest pålidelig med mindst 15-20 punkter"))
  }

  return(list(valid = TRUE, warnings = warnings))
}

## Generér SPC plot med tilpasset styling
