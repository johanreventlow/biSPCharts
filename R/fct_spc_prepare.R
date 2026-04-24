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

#' Bestem akse-konfiguration fra en forberedt SPC-anmodning
#'
#' Skalerer tids-target/centerline til kanoniske minutter, mapper biSPCharts-
#' tidsenheder til BFHcharts' kanoniske "time", og formaterer target_text som
#' komposit-tid. Returnerer et `spc_axes`-objekt klar til BFHcharts-rendering.
#'
#' @param prepared `spc_prepared` objekt fra `prepare_spc_data()`.
#'
#' @return `spc_axes` S3-objekt.
#' @keywords internal
resolve_axis_units <- function(prepared) {
  options <- prepared$options
  original_y_unit <- options$y_axis_unit %||% "count"
  y_axis_unit <- original_y_unit
  target_value <- options$target_value
  centerline_value <- options$centerline_value
  target_text <- options$target_text

  # Skalér target/centerline til kanoniske minutter hvis y-enheden er en
  # tids-enhed. Brugeren indtaster target i den valgte enhed (fx 90 med
  # time_days = 90 dage), men y-data er allerede i minutter efter step 4b.
  if (is_time_unit(y_axis_unit)) {
    if (!is.null(target_value) && length(target_value) > 0) {
      scaled_target <- parse_time_to_minutes(target_value, input_unit = y_axis_unit)
      log_debug(
        paste0(
          "Skalerer target_value ", target_value, " (", y_axis_unit,
          ") -> ", scaled_target, " min"
        ),
        .context = "BFH_SERVICE"
      )
      target_value <- scaled_target
    }
    if (!is.null(centerline_value) && length(centerline_value) > 0) {
      scaled_cl <- parse_time_to_minutes(centerline_value, input_unit = y_axis_unit)
      log_debug(
        paste0(
          "Skalerer centerline_value ", centerline_value, " (", y_axis_unit,
          ") -> ", scaled_cl, " min"
        ),
        .context = "BFH_SERVICE"
      )
      centerline_value <- scaled_cl
    }
  }

  # BFHcharts 0.8.0's y_axis_unit accepterer kun "count", "percent", "rate", "time".
  # Map de nye biSPCharts-enheder (time_minutes/hours/days) til den kanoniske "time"
  # — data er allerede parsed til minutter (se step 4b i prepare_spc_data).
  if (is_time_unit(y_axis_unit) && !identical(y_axis_unit, "time")) {
    log_debug(
      paste0(
        "Mapper y_axis_unit='", y_axis_unit,
        "' -> 'time' for BFHcharts (data er i kanoniske minutter)"
      ),
      .context = "BFH_SERVICE"
    )
    y_axis_unit <- "time"
  }

  # Formatér target_text som komposit-tid hvis y-enheden er en tids-enhed.
  if (is_time_unit(original_y_unit) &&
    !is.null(target_text) &&
    !is.null(target_value) &&
    length(target_value) > 0) {
    operator_match <- regmatches(
      target_text,
      regexpr("^[<>=]+", target_text)
    )
    operator_prefix <- if (length(operator_match) > 0) operator_match else ""
    formatted_value <- format_time_composite(target_value)
    new_target_text <- paste0(operator_prefix, formatted_value)
    log_debug(
      paste0(
        "Formaterer target_text '", target_text, "' -> '",
        new_target_text, "' (y_axis_unit=", original_y_unit, ")"
      ),
      .context = "BFH_SERVICE"
    )
    target_text <- new_target_text
  }

  # Guard: "percent" kræver nævner — uden nævner er det en fejldetektering
  if (identical(y_axis_unit, "percent") && is.null(prepared$n_var)) {
    log_warn(
      paste(
        "y_axis_unit='percent' uden nævner (n_var=NULL) for chart_type=",
        prepared$chart_type,
        "— overskriver til 'count' for at undgå forkert normalisering"
      ),
      .context = "BFH_SERVICE"
    )
    y_axis_unit <- "count"
  }

  new_spc_axes(
    y_axis_unit = y_axis_unit,
    multiply = prepared$multiply,
    target_value = target_value,
    centerline_value = centerline_value,
    target_text = target_text
  )
}
