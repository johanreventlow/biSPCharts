# utils_server_export.R
# Export helper utilities for server-side operations
# Provides data extraction and formatting for PDF/PNG exports

# EXTRACT SPC STATISTICS ======================================================

#' Extract SPC Statistics from App State
#'
#' Udtraek Anhoej rules statistikker fra app_state til brug i export funktioner.
#' Returnerer named list med expected og actual vaerdier for runs, crossings, outliers.
#'
#' @param app_state Reactive values. Global app state med visualization data.
#'
#' @return List med SPC statistikker eller NULL hvis ikke tilgaengelige.
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
#' @keywords internal
extract_spc_statistics <- function(app_state) {
  safe_operation(
    operation_name = "Extract SPC statistics",
    code = {
      # NOTE: Don't use return() inside safe_operation code blocks!
      result <- NULL

      # Valider app_state eksisterer
      if (is.null(app_state)) {
        log_warn(
          component = "[EXPORT]",
          message = "app_state er NULL - kan ikke udtr\u00e6kke SPC statistikker"
        )
      } else {
        # Hent Anhoej results fra visualization state
        anhoej <- app_state$visualization$anhoej_results

        if (is.null(anhoej)) {
          log_warn(
            component = "[EXPORT]",
            message = "Ingen Anh\u00f8j results tilg\u00e6ngelige"
          )
        } else if (!isTRUE(anhoej$has_valid_data)) {
          # Check om vi har valid data
          log_debug(
            component = "[EXPORT]",
            message = "Anh\u00f8j results ikke valid endnu",
            details = list(message = anhoej$message %||% "Ingen besked")
          )
        } else {
          # Udtraek statistikker
          result <- list(
            runs_expected = anhoej$longest_run_max,
            runs_actual = anhoej$longest_run,
            crossings_expected = anhoej$n_crossings_min,
            crossings_actual = anhoej$n_crossings,
            outliers_expected = 0, # Anhoej rules forventer 0 outliers normalt
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
        message = "Fejl ved udtr\u00e6kning af SPC statistikker",
        details = list(error = e$message)
      )
      NULL
    },
    error_type = "processing"
  )
}

# Details string genereres nu af BFHcharts::bfh_generate_details() automatisk.
# generate_details_string() er fjernet -- se bfh_export_pdf(auto_details).

# VALIDATE DPI INPUT AND CAPABILITY CHECK =====================================

#' Validér DPI-argument til eksport
#'
#' Tjekker at dpi er numerisk og inden for intervallet 72-600.
#' Kaster en typed \code{export_input_error} ved ugyldig vaerdi.
#'
#' @param dpi Numerisk. DPI-vaerdi til validering.
#'
#' @return invisible(dpi) ved succes.
#' @keywords internal
validate_export_dpi <- function(dpi) {
  if (!is.numeric(dpi) || length(dpi) != 1L || is.na(dpi) || dpi < 72 || dpi > 600) {
    rlang::abort(
      paste0("dpi skal vaere numerisk mellem 72 og 600, fik: ", dpi),
      class = c("export_input_error", "spc_error", "error")
    )
  }
  invisible(dpi)
}

# TEMPLATE ASSET INJECTION =====================================================

#' Inject biSPCharts Template Assets into Export Temp Directory
#'
#' Delegerer asset-injection til den private companion-pakke `BFHchartsAssets`.
#' biSPCharts bundler ikke længere proprietære fonts (Mari, Arial) eller
#' hospital-logoer i sit eget repo — disse leveres af `BFHchartsAssets` via
#' privat distribution.
#'
#' Funktionssignatur bevares for bagudkompatibilitet med eksisterende
#' kald-sites (`mod_export_download.R`, samt fallback-pathen i
#' `utils_server_export.R:370`). Kontrakt matcher
#' `BFHcharts::bfh_export_pdf()`'s `inject_assets`-callback parameter.
#'
#' @param template_dir Sti til bfh-template mappen i temp directory
#' @return invisible(TRUE) hvis BFHchartsAssets var tilgængelig og injection
#'   lykkedes; invisible(FALSE) hvis BFHchartsAssets ikke er installeret
#'   eller injection fejlede. Funktionen kaster ikke errors.
#' @keywords internal
inject_template_assets <- function(template_dir) {
  if (!requireNamespace("BFHchartsAssets", quietly = TRUE)) {
    log_warn(
      "BFHchartsAssets ikke tilgaengelig - PDF eksporteres uden hospital-branding. ",
      "Installer BFHchartsAssets for fuld branding (kraever GITHUB_PAT med privat repo-adgang)."
    )
    return(invisible(FALSE))
  }

  safe_operation(
    operation_name = "Inject template assets via BFHchartsAssets",
    code = {
      BFHchartsAssets::inject_bfh_assets(template_dir)
      invisible(TRUE)
    },
    fallback = FALSE
  )
}

# TEMPORARY: Fjern når BFHcharts eksporterer bfh_create_typst_document,
# bfh_extract_spc_stats og bfh_merge_metadata. Opret issue i BFHcharts-repo:
# getFromNamespace() bryder CRAN-konventioner og CLAUDE.md-regel om aldrig at
# implementere ekstern pakke-funktionalitet internt. Eskalering dokumenteret i
# commit chore: marker bfhcharts_internal som TEMPORARY (Phase 3).
bfhcharts_internal <- function(name) {
  getFromNamespace(name, "BFHcharts")
}

# GET HOSPITAL NAME ===========================================================

#' Get Hospital Name for Export
#'
#' Henter hospital navn fra branding config til brug i exports.
#' Fallback til default hvis ikke tilgaengeligt.
#'
#' @return Character. Hospital navn.
#'
#' @examples
#' \dontrun{
#' hospital <- get_hospital_name_for_export()
#' }
#'
#' @family export_helpers
#' @keywords internal
get_hospital_name_for_export <- function() {
  # Proev at hente fra branding config
  if (exists("get_hospital_name") && is.function(get_hospital_name)) {
    # Silent-fail korrekt: hospital-navn til eksport er ikke-essentiel (valgfri metadata)
    name <- tryCatch(
      get_hospital_name(),
      error = function(e) NULL # nolint: swallowed_error_linter
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
  "Bispebjerg og Frederiksberg Hospital"
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
#' Funktionen bruger Typst's direkte PNG output (mere effektivt end PDF->PNG):
#' 1. Genererer chart PNG via \code{ggplot2::ggsave()}
#' 2. Opretter Typst dokument via BFHcharts' interne Typst-helper
#' 3. Kompilerer direkte til PNG via \code{quarto typst compile -f png}
#'
#' PNG filen er midlertidig og vil blive slettet naar R session afsluttes.
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
#' @keywords internal
generate_pdf_preview <- function(bfh_qic_result,
                                 metadata,
                                 dpi = 150) {
  # Valid\u00e9r dpi inden safe_operation -- kaster export_input_error ved ugyldig vaerdi
  validate_export_dpi(dpi)

  safe_operation(
    operation_name = "Generate PDF preview",
    code = {
      # NOTE: Don't use return() inside safe_operation code blocks!
      # Use conditional flow with result variable instead

      result <- NULL

      # Valider inputs - must be bfh_qic_result object
      valid_input <- !is.null(bfh_qic_result) && BFHcharts::is_bfh_qic_result(bfh_qic_result)

      if (!valid_input) {
        log_warn(
          component = "[EXPORT]",
          message = "Ingen valid bfh_qic_result til PDF preview"
        )
      } else {
        # Tjek Quarto og Typst-kapabilitet via check_quarto_capability()
        capability <- check_quarto_capability()
        quarto_ok <- isTRUE(capability$available) && isTRUE(capability$typst_supported)

        if (!quarto_ok) {
          log_warn(
            component = "[EXPORT]",
            message = "Quarto eller Typst ikke tilg\u00e6ngelig - PDF preview kan ikke genereres",
            details = list(capability = capability)
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
          # R/config_plot_contexts.R: export_pdf = 200x120mm @ 300 DPI
          ggplot2::ggsave(
            filename = chart_png,
            plot = plot_no_title,
            width = 200 / 25.4, # mm to inches (aligned with export_pdf config)
            height = 120 / 25.4, # mm to inches (aligned with export_pdf config)
            dpi = 300,
            units = "in",
            device = "png"
          )

          # 2. Extract SPC stats using BFHcharts public API.
          #    Send hele bfh_qic_result (ikke kun $summary) saa S3-dispatch sender
          #    os til bfh_extract_spc_stats.bfh_qic_result(), som udfylder
          #    outliers_actual (seneste part, total) til tabellen. Uden dette kald
          #    ville tabellen "OBS. UDEN FOR KONTROLGRAeNSE" vaere tom i preview.
          spc_stats <- bfhcharts_internal("bfh_extract_spc_stats")(bfh_qic_result)

          # 3. Merge metadata with chart title
          metadata_full <- bfhcharts_internal("bfh_merge_metadata")(metadata, chart_title)

          # 4. Create Typst document.
          # bfh_create_typst_document() er internal i BFHcharts (ikke i public
          # NAMESPACE) -- tilgaaes via bfhcharts_internal()-helper.
          typst_file <- file.path(temp_dir, "document.typ")
          bfhcharts_internal("bfh_create_typst_document")(
            chart_image = chart_png,
            output = typst_file,
            metadata = metadata_full,
            spc_stats = spc_stats,
            template = "bfh-diagram"
          )

          # 4b. Inject biSPCharts fonts+images (BFHcharts' repo har dem ikke)
          inject_template_assets(file.path(temp_dir, "bfh-template"))

          # 5. Compile Typst directly to PNG (more efficient than PDF->PNG)
          temp_png <- tempfile(fileext = ".png")

          # Use quarto typst compile with PNG format.
          # --ignore-system-fonts: undgaar at Typst picker system-Mari-varianter
          # (fx Mari Heavy.otf med metadata style=Heavy,Regular) som regular weight.
          font_path <- file.path(temp_dir, "bfh-template", "fonts")
          compile_result <- system2(
            "quarto",
            args = c(
              "typst", "compile",
              typst_file,
              temp_png,
              "-f", "png",
              "--ppi", as.character(dpi),
              "--font-path", font_path,
              "--ignore-system-fonts"
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
              message = "PDF preview genereret succesfuldt (Typst\u2192PNG)",
              details = list(
                png = temp_png,
                size_kb = round(file.size(temp_png) / 1024, 1),
                dpi = dpi
              )
            )

            result <- temp_png
          }
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
