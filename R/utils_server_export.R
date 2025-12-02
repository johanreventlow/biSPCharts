# utils_server_export.R
# Export helper utilities for server-side operations
# Provides data extraction and formatting for PDF/PowerPoint/PNG exports

# EXTRACT SPC STATISTICS ======================================================

#' Extract SPC Statistics from App State
#'
#' Udtræk Anhøj rules statistikker fra app_state til brug i export funktioner.
#' Returnerer named list med expected og actual værdier for runs, crossings, outliers.
#'
#' @param app_state Reactive values. Global app state med visualization data.
#'
#' @return List med SPC statistikker eller NULL hvis ikke tilgængelige.
#'   Liste indeholder: runs_expected, runs_actual, crossings_expected,
#'   crossings_actual, outliers_expected, outliers_actual
#'
#' @examples
#' \dontrun{
#' spc_stats <- extract_spc_statistics(app_state)
#' if (!is.null(spc_stats)) {
#'   print(paste("Runs:", spc_stats$runs_actual))
#' }
#' }
#'
#' @family export_helpers
#' @export
extract_spc_statistics <- function(app_state) {
  safe_operation(
    operation_name = "Extract SPC statistics",
    code = {
      # NOTE: Don't use return() inside safe_operation code blocks!
      result <- NULL

      # Validér app_state eksisterer
      if (is.null(app_state)) {
        log_warn(
          component = "[EXPORT]",
          message = "app_state er NULL - kan ikke udtrække SPC statistikker"
        )
      } else {
        # Hent Anhøj results fra visualization state
        anhoej <- app_state$visualization$anhoej_results

        if (is.null(anhoej)) {
          log_warn(
            component = "[EXPORT]",
            message = "Ingen Anhøj results tilgængelige"
          )
        } else if (!isTRUE(anhoej$has_valid_data)) {
          # Check om vi har valid data
          log_debug(
            component = "[EXPORT]",
            message = "Anhøj results ikke valid endnu",
            details = list(message = anhoej$message %||% "Ingen besked")
          )
        } else {
          # Udtræk statistikker
          result <- list(
            runs_expected = anhoej$longest_run_max,
            runs_actual = anhoej$longest_run,
            crossings_expected = anhoej$n_crossings_min,
            crossings_actual = anhoej$n_crossings,
            outliers_expected = 0, # Anhøj rules forventer 0 outliers normalt
            outliers_actual = anhoej$out_of_control_count %||% 0
          )

          log_debug(
            component = "[EXPORT]",
            message = "SPC statistikker udtrukket succesfuldt",
            details = list(
              runs = sprintf("%s/%s", result$runs_actual, result$runs_expected),
              crossings = sprintf("%s/%s", result$crossings_actual, result$crossings_expected),
              outliers = result$outliers_actual
            )
          )
        }
      }

      result
    },
    fallback = function(e) {
      log_error(
        component = "[EXPORT]",
        message = "Fejl ved udtrækning af SPC statistikker",
        details = list(error = e$message)
      )
      NULL
    },
    error_type = "processing"
  )
}

# GENERATE DETAILS STRING =====================================================

#' Generate Details String for Export
#'
#' Generér detalje-streng med periode info, gennemsnit og nuværende niveau
#' til brug i PDF/PowerPoint exports.
#'
#' @param app_state Reactive values. Global app state med data og columns.
#' @param format Character. Format af output ("short" eller "full"). Default: "full".
#'
#' @return Character string med detaljer eller NULL hvis data ikke tilgængelig.
#'
#' @examples
#' \dontrun{
#' details <- generate_details_string(app_state)
#' # Returns: "Periode: jan. 2024 – dec. 2024 • Gns.: 42.5 • Seneste: 45.2"
#' }
#'
#' @family export_helpers
#' @export
generate_details_string <- function(app_state, format = c("full", "short")) {
  format <- match.arg(format)

  safe_operation(
    operation_name = "Generate details string",
    code = {
      # NOTE: Don't use return() inside safe_operation code blocks!
      result <- NULL

      # Validér app_state og data
      if (is.null(app_state) || is.null(app_state$data$current_data)) {
        log_warn(
          component = "[EXPORT]",
          message = "Ingen data tilgængelig for details string"
        )
      } else {
        data <- app_state$data$current_data
        x_col <- app_state$columns$mappings$x_column
        y_col <- app_state$columns$mappings$y_column

        if (is.null(x_col) || is.null(y_col)) {
          log_warn(
            component = "[EXPORT]",
            message = "x eller y kolonne ikke mappet"
          )
        } else {
          # Udtræk værdier
          x_values <- data[[x_col]]
          y_values <- data[[y_col]]

          # Validér at vi har data
          if (length(y_values) > 0) {
            # Beregn statistikker
            mean_value <- mean(y_values, na.rm = TRUE)
            latest_value <- tail(y_values[!is.na(y_values)], 1)
            n_observations <- sum(!is.na(y_values))

            # Periode info (hvis x er dato)
            period_str <- NULL
            if (inherits(x_values, "Date") || inherits(x_values, "POSIXt")) {
              valid_dates <- x_values[!is.na(x_values)]
              if (length(valid_dates) > 0) {
                start_date <- min(valid_dates)
                end_date <- max(valid_dates)

                # Dansk dato formatering
                start_fmt <- format(start_date, "%b. %Y")
                end_fmt <- format(end_date, "%b. %Y")

                period_str <- sprintf("Periode: %s – %s", start_fmt, end_fmt)
              }
            }

            # Byg details string
            parts <- c()

            if (!is.null(period_str)) {
              parts <- c(parts, period_str)
            }

            parts <- c(parts, sprintf("Antal obs.: %d", n_observations))

            if (format == "full") {
              parts <- c(parts, sprintf("Gennemsnit: %.1f", mean_value))

              if (length(latest_value) > 0) {
                parts <- c(parts, sprintf("Seneste: %.1f", latest_value))
              }
            }

            result <- paste(parts, collapse = " • ")

            log_debug(
              component = "[EXPORT]",
              message = "Details string genereret",
              details = list(
                format = format,
                n_obs = n_observations,
                output = result
              )
            )
          }
        }
      }

      result
    },
    fallback = function(e) {
      log_error(
        component = "[EXPORT]",
        message = "Fejl ved generering af details string",
        details = list(error = e$message)
      )
      NULL
    },
    error_type = "processing"
  )
}

# CHECK QUARTO AVAILABILITY ===================================================

#' Check if Quarto is Available
#'
#' Tjekker om Quarto CLI er tilgængelig på systemet.
#' Bruges til at vise/skjule PDF export option baseret på Quarto tilgængelighed.
#'
#' @return Logical. Altid TRUE da Quarto er inkluderet i RStudio.
#'
#' @note
#' Denne funktion returnerer altid TRUE, da Quarto er bundled med RStudio.
#' BFHcharts::bfh_export_pdf() håndterer Quarto errors internt.
#'
#' @examples
#' \dontrun{
#' if (quarto_available()) {
#'   # Enable PDF export (altid TRUE)
#' }
#' }
#'
#' @family export_helpers
#' @export
quarto_available <- function() {
  # Altid TRUE - Quarto er inkluderet i RStudio
  # BFHcharts::quarto_available() er ikke exporteret, så vi undgår namespace fejl
  TRUE
}

# GET HOSPITAL NAME ===========================================================

#' Get Hospital Name for Export
#'
#' Henter hospital navn fra branding config til brug i exports.
#' Fallback til default hvis ikke tilgængeligt.
#'
#' @return Character. Hospital navn.
#'
#' @examples
#' \dontrun{
#' hospital <- get_hospital_name_for_export()
#' }
#'
#' @family export_helpers
#' @export
get_hospital_name_for_export <- function() {
  # Prøv at hente fra branding config
  if (exists("get_hospital_name") && is.function(get_hospital_name)) {
    name <- tryCatch(
      get_hospital_name(),
      error = function(e) NULL
    )

    if (!is.null(name) && nchar(name) > 0) {
      return(name)
    }
  }

  # Fallback til global variabel hvis den eksisterer
  if (exists("HOSPITAL_NAME", envir = .GlobalEnv)) {
    name <- get("HOSPITAL_NAME", envir = .GlobalEnv)
    if (!is.null(name) && nchar(name) > 0) {
      return(name)
    }
  }

  # Final fallback
  return("Bispebjerg og Frederiksberg Hospital")
}

# GENERATE PDF PREVIEW ========================================================

#' Generate PDF Preview Image
#'
#' Genererer PNG preview af PDF layout direkte fra Typst.
#' Bruges af export module til at vise PDF layout preview i browseren.
#'
#' @param bfh_qic_result bfh_qic_result object from BFHcharts::bfh_qic() or generateSPCPlot()$bfh_qic_result.
#' @param metadata List. PDF metadata (hospital, department, title, analysis, etc.).
#' @param dpi Numeric. DPI/PPI for PNG rendering (default: 150).
#'
#' @return Character path til PNG preview fil eller NULL ved fejl.
#'
#' @details
#' Funktionen bruger Typst's direkte PNG output (mere effektivt end PDF→PNG):
#' 1. Genererer chart PNG via \code{ggplot2::ggsave()}
#' 2. Opretter Typst dokument via \code{BFHcharts::bfh_create_typst_document()}
#' 3. Kompilerer direkte til PNG via \code{quarto typst compile -f png}
#'
#' PNG filen er midlertidig og vil blive slettet når R session afsluttes.
#'
#' @examples
#' \dontrun{
#' # bfh_qic_result comes from BFHcharts::bfh_qic() or generateSPCPlot()$bfh_qic_result
#' metadata <- list(
#'   hospital = "Test Hospital",
#'   department = "Test Dept",
#'   title = "Test Chart",
#'   analysis = "Test analysis",
#'   details = "Test details",
#'   data_definition = NULL,
#'   author = "Test Author",
#'   date = Sys.Date()
#' )
#'
#' preview_path <- generate_pdf_preview(bfh_qic_result, metadata)
#' if (!is.null(preview_path)) {
#'   # Display preview image
#' }
#' }
#'
#' @family export_helpers
#' @export
generate_pdf_preview <- function(bfh_qic_result,
                                 metadata,
                                 dpi = 150) {
  safe_operation(
    operation_name = "Generate PDF preview",
    code = {
      # NOTE: Don't use return() inside safe_operation code blocks!
      # Use conditional flow with result variable instead

      result <- NULL

      # Validér inputs - must be bfh_qic_result object
      valid_input <- !is.null(bfh_qic_result) && BFHcharts::is_bfh_qic_result(bfh_qic_result)

      if (!valid_input) {
        log_warn(
          component = "[EXPORT]",
          message = "Ingen valid bfh_qic_result til PDF preview"
        )
      } else if (!quarto_available()) {
        # Check Quarto availability (includes Typst)
        log_warn(
          component = "[EXPORT]",
          message = "Quarto ikke tilgængelig - PDF preview kan ikke genereres"
        )
      } else {
        # Create temp directory for Typst compilation
        temp_dir <- tempfile("bfh_preview_")
        dir.create(temp_dir, recursive = TRUE)

        log_debug(
          component = "[EXPORT]",
          message = "Genererer PDF preview via Typst PNG",
          details = list(temp_dir = temp_dir, dpi = dpi)
        )

        # 1. Generate chart PNG (same as bfh_export_pdf does internally)
        chart_title <- bfh_qic_result$config$chart_title
        if (is.null(chart_title)) chart_title <- ""

        plot_no_title <- bfh_qic_result$plot + ggplot2::labs(title = NULL, subtitle = NULL)
        chart_png <- file.path(temp_dir, "chart.png")

        # Use same dimensions as export_pdf config for consistency
        # R/config_plot_contexts.R: export_pdf = 200×120mm @ 300 DPI
        ggplot2::ggsave(
          filename = chart_png,
          plot = plot_no_title,
          width = 200 / 25.4, # mm to inches (aligned with export_pdf config)
          height = 120 / 25.4, # mm to inches (aligned with export_pdf config)
          dpi = 300,
          units = "in",
          device = "png"
        )

        # 2. Extract SPC stats using BFHcharts public API
        spc_stats <- BFHcharts::bfh_extract_spc_stats(bfh_qic_result$summary)

        # 3. Merge metadata with chart title
        metadata_full <- BFHcharts::bfh_merge_metadata(metadata, chart_title)

        # 4. Create Typst document
        typst_file <- file.path(temp_dir, "document.typ")
        BFHcharts::bfh_create_typst_document(
          chart_image = chart_png,
          output = typst_file,
          metadata = metadata_full,
          spc_stats = spc_stats,
          template = "bfh-diagram2"
        )

        # 5. Compile Typst directly to PNG (more efficient than PDF→PNG)
        temp_png <- tempfile(fileext = ".png")

        # Register temp file for automatic cleanup when R session ends
        # This prevents temp file accumulation during long sessions
        reg.finalizer(
          environment(),
          function(e) {
            if (exists("temp_png", envir = e) && file.exists(get("temp_png", envir = e))) {
              unlink(get("temp_png", envir = e))
            }
          },
          onexit = TRUE
        )

        # Use quarto typst compile with PNG format
        compile_result <- system2(
          "quarto",
          args = c(
            "typst", "compile",
            typst_file,
            temp_png,
            "-f", "png",
            "--ppi", as.character(dpi)
          ),
          stdout = TRUE,
          stderr = TRUE
        )

        # Cleanup temp directory
        unlink(temp_dir, recursive = TRUE)

        # Check exit status and validate PNG
        exit_status <- attr(compile_result, "status")
        if (!is.null(exit_status) && exit_status != 0) {
          log_error(
            component = "[EXPORT]",
            message = "Quarto Typst compilation failed",
            details = list(
              exit_code = exit_status,
              stdout = paste(compile_result, collapse = "\n")
            )
          )
        } else if (!file.exists(temp_png)) {
          log_error(
            component = "[EXPORT]",
            message = "PNG preview compilation failed - file not generated",
            details = list(output = paste(compile_result, collapse = "\n"))
          )
        } else {
          log_info(
            component = "[EXPORT]",
            message = "PDF preview genereret succesfuldt (Typst→PNG)",
            details = list(
              png = temp_png,
              size_kb = round(file.size(temp_png) / 1024, 1),
              dpi = dpi
            )
          )

          result <- temp_png
        }
      }

      result
    },
    fallback = function(e) {
      log_error(
        component = "[EXPORT]",
        message = "PDF preview generation failed",
        details = list(error = e$message)
      )
      NULL
    },
    error_type = "processing"
  )
}
