# fct_spc_prepare.R
# Data-forberedelse for SPC pipeline.

#' Filtrer og forbered SPC-data fra en valideret spc_request
#'
#' Parser, konverterer og filtrerer input-data. Returnerer et `spc_prepared`-objekt
#' klar til akse-opsætning og BFHcharts-rendering. Kaster `spc_prepare_error`
#' ved parsing- eller filtering-fejl.
#'
#' @param req `spc_request` objekt fra `validate_spc_request()`.
#'
#' @return `spc_prepared` S3-objekt.
#' @keywords internal
prepare_spc_data <- function(req) {
  n_rows_original <- nrow(req$data)
  y_axis_unit_early <- req$options$y_axis_unit %||% "count"

  # 4. Filtrer komplette datarækker
  complete_data <- filter_complete_spc_data(
    data = req$data,
    y_col = req$y_var,
    n_col = req$n_var,
    x_col = req$x_var
  )

  log_debug(
    paste(
      "After filter_complete_spc_data - x column type:",
      "x(", req$x_var, ")=", class(complete_data[[req$x_var]])[1]
    ),
    .context = "BFH_SERVICE"
  )

  if (nrow(complete_data) == 0) {
    spc_abort(
      "No valid data rows found after filtering",
      class = "spc_prepare_error"
    )
  }
  if (nrow(complete_data) < 3) {
    spc_abort(
      paste0(
        "Insufficient data points: ",
        nrow(complete_data),
        ". Minimum 3 points required for SPC charts"
      ),
      class = "spc_prepare_error"
    )
  }

  # 4b. Parse tids-input til kanoniske minutter hvis y-enheden er en tids-enhed.
  # Sker FØR parse_and_validate_spc_data for at undgå at HH:MM-strenge
  # bliver til NA i as.numeric()-fallbacken.
  if (is_time_unit(y_axis_unit_early)) {
    complete_data[[req$y_var]] <- parse_time_to_minutes(
      complete_data[[req$y_var]],
      input_unit = y_axis_unit_early
    )
    log_debug(
      paste0(
        "Parsede tids-kolonne '", req$y_var,
        "' til kanoniske minutter via input_unit='", y_axis_unit_early, "'"
      ),
      .context = "BFH_SERVICE"
    )
  }

  # 5. Parse og valider numerisk data
  y_data_raw <- complete_data[[req$y_var]]
  n_data_raw <- if (!is.null(req$n_var)) complete_data[[req$n_var]] else NULL

  validated <- parse_and_validate_spc_data(
    y_data = y_data_raw,
    n_data = n_data_raw,
    y_col = req$y_var,
    n_col = req$n_var
  )

  # 6. Applicer parsede numeriske værdier tilbage til complete_data
  complete_data[[req$y_var]] <- validated$y_data
  if (!is.null(req$n_var)) {
    complete_data[[req$n_var]] <- validated$n_data
  }

  log_debug(
    paste(
      "After numeric parsing - Data types:",
      "y(", req$y_var, ")=", class(complete_data[[req$y_var]])[1],
      if (!is.null(req$n_var)) {
        paste0(", n(", req$n_var, ")=", class(complete_data[[req$n_var]])[1])
      } else {
        ""
      },
      " | First 3 y values:", paste(head(complete_data[[req$y_var]], 3), collapse = ", ")
    ),
    .context = "BFH_SERVICE"
  )

  # 6c. Parse x-akse til Date/POSIXct hvis muligt, ellers til numerisk sekvens.
  # BFHcharts kræver korrekte dato-typer for x-aksen.
  if (!inherits(complete_data[[req$x_var]], c("Date", "POSIXct", "POSIXt"))) {
    log_debug(
      paste("X column is character, attempting to parse to Date:", req$x_var),
      .context = "BFH_SERVICE"
    )

    parsed_x <- tryCatch(
      {
        x_raw <- complete_data[[req$x_var]]
        parsed <- lubridate::parse_date_time(
          x_raw,
          orders = c("dmy", "ymd", "mdy", "dmy HMS", "ymd HMS", "mdy HMS"),
          quiet = TRUE
        )
        if (!is.null(parsed) && !all(is.na(parsed))) {
          if (all(lubridate::hour(parsed) == 0 & lubridate::minute(parsed) == 0)) {
            as.Date(parsed)
          } else {
            parsed
          }
        } else {
          NULL
        }
      },
      error = function(e) {
        log_warn(
          paste("Failed to parse x column as date:", e$message),
          .context = "BFH_SERVICE"
        )
        NULL
      }
    )

    if (!is.null(parsed_x)) {
      complete_data[[req$x_var]] <- parsed_x
      log_info(
        paste(
          "X column parsed successfully:",
          req$x_var, "→", class(complete_data[[req$x_var]])[1],
          "| First value:", as.character(complete_data[[req$x_var]][1])
        ),
        .context = "BFH_SERVICE"
      )
    } else {
      # Dato-parsing fejlede — x-kolonnen er ren tekst (fx "Uge 1", "Uge 2")
      # Konverter til numerisk sekvens og gem originale labels til x-aksen
      log_info(
        paste("X column is text, converting to numeric sequence:", req$x_var),
        .context = "BFH_SERVICE"
      )
      complete_data[[paste0(".x_labels_", req$x_var)]] <- complete_data[[req$x_var]]
      complete_data[[req$x_var]] <- seq_len(nrow(complete_data))
    }
  }

  new_spc_prepared(
    data = complete_data,
    x_var = req$x_var,
    y_var = req$y_var,
    chart_type = req$chart_type,
    n_var = req$n_var,
    cl_var = req$cl_var,
    freeze_var = req$freeze_var,
    part_var = req$part_var,
    notes_column = req$notes_column,
    multiply = req$multiply,
    options = req$options,
    n_rows_original = n_rows_original,
    n_rows_filtered = nrow(complete_data)
  )
}
