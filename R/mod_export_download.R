# ==============================================================================
# mod_export_download.R
# ==============================================================================
# DOWNLOAD HANDLER MODULE FOR EXPORT
#
# Purpose: Extract download handler logic from mod_export_server.R.
#          Manages PDF and PNG export file generation and download.
#
# Extracted from: mod_export_server.R (Phase 2b refactoring)
# Depends on: app_state, input, session, build_export_plot (utils_export_helpers.R)
# ==============================================================================

#' Register Download Handler
#'
#' Sets up downloadHandler that generates export files in multiple formats
#' (PDF via Typst, PNG).
#'
#' @param output Output object for rendering
#' @param input Input object containing UI inputs
#' @param session Shiny session object
#' @param app_state Global app state containing data and column mappings
#'
#' @return NULL (side effect: registers output handler with Shiny)
#'
#' @keywords internal
register_export_downloads <- function(output, input, session, app_state) {
  output$download_export <- shiny::downloadHandler(
    filename = function() {
      format <- input$export_format %||% "pdf"
      filename <- generate_export_filename(
        format = format,
        title = input$export_title %||% "",
        department = input$export_department %||% ""
      )

      log_info(
        .context = "EXPORT_MODULE",
        message = "Download initiated",
        details = list(format = format, filename = filename)
      )

      filename
    },
    content = function(file) {
      shiny::req(app_state)
      shiny::req(app_state$data$current_data)

      format <- input$export_format %||% "pdf"

      safe_operation(
        operation_name = paste("Export", toupper(format)),
        code = {
          if (format == "pdf") {
            generate_pdf_export(input, app_state, file)
          } else if (format == "png") {
            generate_png_export(input, app_state, file)
          } else {
            stop(paste("Ukendt format:", format))
          }

          log_info(
            .context = "EXPORT_MODULE",
            message = "Export completed successfully",
            details = list(format = format, file = basename(file))
          )
        },
        fallback = function(e) {
          log_error(
            .context = "EXPORT_MODULE",
            message = "Export failed",
            details = list(format = format, error = e$message)
          )
          shiny::showNotification(
            paste0(
              "Eksport fejlede. Pr\u00f8v igen, ",
              "eller kontakt Dataenheden hvis problemet forts\u00e6tter."
            ),
            type = "error",
            duration = 10
          )
        },
        error_type = "processing"
      )
    }
  )
}

# === FORMAT-SPECIFIC EXPORT FUNCTIONS =======================================

#' Generate PDF Export
#'
#' @param input Shiny input object
#' @param app_state Global app state
#' @param file Output file path
#' @keywords internal
generate_pdf_export <- function(input, app_state, file) {
  log_debug(.context = "EXPORT_MODULE", message = "PDF export starting")

  validate_export_inputs(
    format = "pdf",
    title = input$export_title,
    department = input$export_department,
    hospital = input$export_hospital
  )

  # Generer SPC plot via faelles helper
  pdf_plot_result <- build_export_plot(
    app_state = app_state,
    title_input = input$export_title %||% "",
    dept_input = input$export_department %||% "",
    plot_context = "export_pdf"
  )

  if (is.null(pdf_plot_result) || is.null(pdf_plot_result$bfh_qic_result)) {
    stop("Ingen plot tilg\u00e6ngeligt til eksport")
  }

  # Advarsel-watermark til kort serie (#417)
  # Tilfoejes til data_definition (pdf_description) da BFHcharts' Typst-template
  # ikke har et dedikeret short_series_warning-felt. Concat er den sikre
  # fallback der ikke kraever aendring i ekstern pakke.
  n_pts_export <- if (!is.null(app_state$data$current_data)) {
    nrow(app_state$data$current_data)
  } else {
    NA_integer_
  }
  short_series_note <- if (!is.na(n_pts_export) && n_pts_export < get_spc_warning_threshold()) {
    paste0(
      "Kort serie (n=", n_pts_export, "): ",
      "Anhøj-rules er upålidelige under ", get_spc_warning_threshold(), " datapunkter."
    )
  } else {
    NULL
  }
  base_description <- input$pdf_description %||% ""
  data_definition_with_note <- if (!is.null(short_series_note) && nchar(short_series_note) > 0) {
    if (nchar(trimws(base_description)) > 0) {
      paste0(base_description, "\n\n", short_series_note)
    } else {
      short_series_note
    }
  } else {
    base_description
  }

  # PDF-specifik metadata til BFHcharts Typst-template
  metadata <- list(
    hospital = if (nzchar(input$export_hospital %||% "")) input$export_hospital else get_hospital_name_for_export(),
    department = input$export_department,
    title = input$export_title,
    analysis = input$pdf_improvement,
    data_definition = data_definition_with_note,
    date = Sys.Date()
  )

  result <- BFHcharts::bfh_export_pdf(
    x = pdf_plot_result$bfh_qic_result,
    output = file,
    metadata = metadata,
    template = "bfh-diagram",
    auto_analysis = FALSE,
    inject_assets = inject_template_assets
  )

  if (is.null(result) || !file.exists(file)) {
    stop("PDF generation failed - file not created")
  }

  shiny::showNotification("PDF genereret og downloadet", type = "message", duration = 3)
}

#' Generate PNG Export
#'
#' @param input Shiny input object
#' @param app_state Global app state
#' @param file Output file path
#' @keywords internal
generate_png_export <- function(input, app_state, file) {
  log_debug(.context = "EXPORT_MODULE", message = "PNG export starting")

  dpi <- 150

  # Brugerens egne dimensioner (px)
  width_px <- as.numeric(input$png_width %||% 1920)
  height_px <- as.numeric(input$png_height %||% 1080)
  width_inches <- width_px / dpi
  height_inches <- height_px / dpi

  final_width_px <- width_px
  final_height_px <- height_px

  validate_export_inputs(
    format = "png",
    title = input$export_title,
    department = input$export_department,
    width = final_width_px,
    height = final_height_px
  )

  # Generer SPC plot med PNG-specifik DPI og dimensioner
  png_plot_result <- build_export_plot(
    app_state = app_state,
    title_input = input$export_title %||% "",
    dept_input = input$export_department %||% "",
    plot_context = "export_png",
    override_width_px = final_width_px,
    override_height_px = final_height_px,
    override_dpi = dpi
  )

  if (is.null(png_plot_result) || is.null(png_plot_result$bfh_qic_result)) {
    stop("Ingen plot tilg\u00e6ngeligt til PNG-eksport")
  }

  # Tilfoej subtitle (hospital + afdeling) og margin til PNG-plottet
  plot <- png_plot_result$bfh_qic_result$plot

  dept_text <- trimws(input$export_department %||% "")
  if (nchar(dept_text) > 0) {
    plot <- plot + ggplot2::labs(subtitle = dept_text)
  }

  footnote_text <- trimws(input$export_footnote %||% "")
  if (nchar(footnote_text) > 0) {
    plot <- plot + ggplot2::labs(caption = footnote_text)
  }

  # Margin for paenere PNG-output (top, right, bottom, left)
  plot <- plot + ggplot2::theme(
    plot.margin = ggplot2::margin(8, 8, 8, 8, "mm")
  )

  png_plot_result$bfh_qic_result$plot <- plot

  # Konverter inches til mm (BFHcharts bruger mm)
  result <- BFHcharts::bfh_export_png(
    x = png_plot_result$bfh_qic_result,
    output = file,
    width_mm = width_inches * 25.4,
    height_mm = height_inches * 25.4,
    dpi = dpi
  )

  if (is.null(result) || !file.exists(file)) {
    stop("PNG generation failed - file not created")
  }

  shiny::showNotification("PNG genereret og downloadet", type = "message", duration = 3)
}
