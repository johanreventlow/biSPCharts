# ==============================================================================
# mod_export_server.R
# ==============================================================================
# MAIN ORCHESTRATOR FOR EXPORT MODULE
#
# Purpose: Coordinate initialization and integration of all export sub-modules
#          (analysis auto-generation, AI suggestions, download handlers).
#          Acts as orchestrator for preview rendering and exports.
#
# Architecture Pattern:
#   Module initialization -> Register observers from sub-modules -> UI rendering
#
# Phase 2b Refactoring: IN PROGRESS (400 LOC target, from 1157 LOC)
#   - Stage 1: Analysis Auto-Generation (mod_export_analysis.R)
#   - Stage 2: AI Suggestion Integration (mod_export_ai.R)
#   - Stage 3: Download Handlers (mod_export_download.R)
#   - Stage 4: Helper Utilities (utils_export_helpers.R)
#   - Stage 5: Orchestrator & Preview Rendering (THIS FILE)
#
# Key design principles:
#   - Clear separation of concerns (each module has single responsibility)
#   - Reactive chain isolation (preview -> rendering, separate from download logic)
#   - Error handling (safe_operation, graceful fallbacks)
#   - Observability (structured logging, debug context)
# ==============================================================================

#' Export Module Server
#'
#' Server logik for eksport af SPC charts.
#' Haandterer live preview og download af charts i PDF og PNG formater.
#'
#' @param id Module ID
#' @param app_state Reactive values. Global app state med data, columns og chart config.
#'   Tilgaas read-only - ingen modificering af state.
#' @param parent_session Shiny session. Parent session for navbar navigation (Tilbage-knap).
#'
#' @return Liste med reactive values for module status
#' @family export_modules
#' @keywords internal
mod_export_server <- function(id, app_state, parent_session = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    # === INITIALIZATION ======================================================
    ns <- session$ns

    # Log module initialization
    log_info(
      .context = "EXPORT_MODULE",
      message = "Export module initialized"
    )

    # Tilbage-knap: Trin 3 -> Trin 2
    shiny::observeEvent(input$back_to_analysis, {
      if (!is.null(parent_session)) {
        bslib::nav_select("main_navbar", selected = "analyser", session = parent_session)
      }
    })

    # Tab-guard: tjek om brugeren er paa eksport-fanen
    # Bruges af export reactives for at undgaa beregning paa trin 1/2
    is_on_export_tab <- shiny::reactive({
      # Tilgaa root session navbar input via parent session
      root_input <- session$rootScope()$input
      active_tab <- root_input$main_navbar
      identical(active_tab, "eksporter")
    })

    # PREVIEW GENERATION ======================================================

    # Export plot reactive - regenerates plot with export-specific dimensions
    # Issue #61: Separate plot generation with context "export_preview" (800x450px)
    # Issue #62: Cache isolated from analysis context
    # Debounced to prevent excessive re-rendering when user types metadata
    export_plot <- shiny::reactive({
      # Guard: kun beregn naar brugeren er paa eksport-fanen
      shiny::req(is_on_export_tab())

      # chart_type can be NULL at startup - use default "run" as fallback
      chart_type <- app_state$columns$mappings$chart_type %||% "run"

      # Single req() call for all required dependencies
      shiny::req(
        app_state,
        app_state$data$current_data,
        app_state$columns$mappings$x_column,
        app_state$columns$mappings$y_column,
        chart_type,
        nchar(trimws(chart_type)) > 0
      )

      # NOTE: We do NOT require app_state$visualization$plot_object here because:
      # 1. export_plot() regenerates independently (doesn't clone Analyse-side plot)
      # 2. All required data is in app_state$columns$mappings (set by autodetection)
      # 3. Requiring plot_object would block PNG preview when user navigates
      #    directly to Export-side before visiting Analyse-side

      log_debug(
        .context = "EXPORT_MODULE",
        message = "export_plot() reactive - all req() checks passed, generating plot"
      )

      # Read export metadata inputs (triggers reactive dependency)
      # Note: Use %||% to ensure reactive dependency is tracked even if NULL
      title_input <- input$export_title %||% ""
      dept_input <- input$export_department %||% ""

      # Beregn preview-dimensioner (samme proportioner som brugerens valg,
      # men skaleret til preview-bredde 800px). Disse SKAL matche renderPlot's
      # width/height for at label-positioner passer korrekt.
      user_w <- as.numeric(input$png_width %||% 1920)
      user_h <- as.numeric(input$png_height %||% 1080)
      if (is.na(user_w) || user_w < 100) user_w <- 1920
      if (is.na(user_h) || user_h < 100) user_h <- 1080
      ratio <- max(0.2, min(5, user_h / user_w))
      preview_width <- 800
      preview_height <- round(800 * ratio)

      # Issue #65: Use shared helper to reduce code duplication
      build_export_plot(
        app_state, title_input, dept_input, "export_preview",
        override_width_px = preview_width,
        override_height_px = preview_height
      )
    }) |> shiny::debounce(millis = 500) # Debounce metadata changes for performance

    # PDF EXPORT PLOT GENERATION ==============================================

    # PDF export reactive - regenerates plot with PDF-specific dimensions
    # This ensures correct label placement for high-res print output
    # (200x120mm @ 300 DPI = ~2362x1417px)
    # Issue #65: Use shared helper to reduce code duplication
    # Issue #67: Helper is undebounced; reactive debounces for preview performance
    pdf_export_plot <- shiny::reactive({
      # Guard: kun beregn naar brugeren er paa eksport-fanen
      shiny::req(is_on_export_tab())

      shiny::req(
        app_state,
        app_state$data$current_data,
        app_state$columns$mappings$x_column,
        app_state$columns$mappings$y_column
      )

      # Read export metadata inputs (triggers reactive dependency)
      title_input <- input$export_title %||% ""
      dept_input <- input$export_department %||% ""

      # Issue #65: Use shared helper with "export_pdf" context
      build_export_plot(app_state, title_input, dept_input, "export_pdf")
    }) |> shiny::debounce(millis = 1000) # Debounce for preview performance

    # EXPORT PREVIEW RENDERING ================================================

    # Export preview renderPlot - displays plot with export metadata
    # Note: BFHcharts already applies hospital theme automatically via BFHtheme::theme_bfh()
    output$export_preview <- shiny::renderPlot(
      {
        log_debug(
          .context = "EXPORT_MODULE",
          message = "renderPlot for export_preview starting"
        )

        spc_result <- export_plot()

        # DEBUG: Explicit logging of actual values
        log_debug(
          .context = "EXPORT_MODULE",
          message = paste(
            "export_plot() returned - is_null:",
            is.null(spc_result),
            "| has_plot:",
            !is.null(spc_result$plot),
            "| class:",
            if (!is.null(spc_result)) paste(class(spc_result), collapse = ",") else "NULL",
            "| names:",
            if (!is.null(spc_result) && is.list(spc_result)) paste(names(spc_result), collapse = ",") else "N/A"
          )
        )

        if (is.null(spc_result) || is.null(spc_result$plot)) {
          # Display placeholder using ggplot2 for consistency
          return(
            ggplot2::ggplot() +
              ggplot2::annotate(
                "text",
                x = 0.5,
                y = 0.5,
                label = "Ingen graf tilg\u00e6ngelig.\nG\u00e5 til hovedsiden for at oprette en SPC-graf.",
                size = 6,
                color = get_hospital_colors()$ui_grey_dark
              ) +
              ggplot2::theme_void()
          )
        }

        # Tilfoej subtitle (hospital + afdeling) og margin til PNG preview
        plot <- spc_result$plot

        dept_text <- trimws(input$export_department %||% "")
        if (nchar(dept_text) > 0) {
          plot <- plot + ggplot2::labs(subtitle = dept_text)
        }

        footnote_text <- trimws(input$export_footnote %||% "")
        if (nchar(footnote_text) > 0) {
          plot <- plot + ggplot2::labs(caption = footnote_text)
        }

        plot + ggplot2::theme(
          plot.margin = ggplot2::margin(5, 5, 5, 5, "mm")
        )
      },
      width = function() {
        800 # Fast preview-bredde
      },
      height = function() {
        # Dynamisk hoejde baseret paa brugerens proportioner
        # Clamp til rimelige vaerdier for at undgaa ragg max_dim fejl
        # mens brugeren redigerer felterne
        w <- as.numeric(input$png_width %||% 1920)
        h <- as.numeric(input$png_height %||% 1080)
        if (is.na(w) || is.na(h) || w < 100 || h < 100) {
          return(450)
        }
        ratio <- max(0.2, min(5, h / w))
        round(800 * ratio)
      },
      res = 96
    )

    # Plot availability reactive - for conditional UI
    output$plot_available <- shiny::reactive({
      !is.null(app_state$data$current_data) &&
        !is.null(app_state$columns$mappings$y_column)
    })
    outputOptions(output, "plot_available", suspendWhenHidden = FALSE)

    # Lazy export preview: kun genberegn naar brugeren er paa eksport-fanen.
    # Shiny genberegner automatisk med aktuelle data naar fanen vises.
    # (Tidligere suspendWhenHidden = FALSE -- se commit c4c0a5d for rollback)
    outputOptions(output, "export_preview", suspendWhenHidden = TRUE)

    # PNG PRESET OBSERVERS ====================================================

    # Opdater width/height naar preset vaelges
    observeEvent(input$png_preset,
      {
        preset <- input$png_preset
        if (is.null(preset) || preset == "custom") {
          return()
        }

        dims <- strsplit(preset, "x")[[1]]
        if (length(dims) != 2) {
          return()
        }

        shiny::updateNumericInput(session, "png_width", value = as.integer(dims[1]))
        shiny::updateNumericInput(session, "png_height", value = as.integer(dims[2]))
      },
      ignoreInit = TRUE
    )

    # Saet dropdown til "Brugerdefineret" naar brugeren aendrer dimensioner manuelt
    observeEvent(list(input$png_width, input$png_height),
      {
        w <- input$png_width
        h <- input$png_height
        preset <- input$png_preset
        if (is.null(w) || is.null(h) || is.null(preset) || preset == "custom") {
          return()
        }

        expected <- paste0(w, "x", h)
        if (expected != preset) {
          shiny::updateSelectInput(session, "png_preset", selected = "custom")
        }
      },
      ignoreInit = TRUE
    )

    # PDF PREVIEW GENERATION ==================================================

    # PDF preview reactive - generates PNG preview of Typst PDF layout
    # Only active when format is "pdf"
    # Debounced metadata-inputs til PDF preview (undgaar re-render per tastetryk)
    debounced_analysis <- shiny::debounce(shiny::reactive(input$pdf_improvement %||% ""), millis = 1000)
    debounced_data_def <- shiny::debounce(shiny::reactive(input$pdf_description %||% ""), millis = 1000)
    debounced_hospital <- shiny::debounce(shiny::reactive(input$export_hospital %||% ""), millis = 1000)

    pdf_preview_image <- shiny::reactive({
      # Only generate for PDF format
      format <- input$export_format %||% "pdf"
      if (format != "pdf") {
        return(NULL)
      }

      # Defensive checks - require valid app_state and data
      shiny::req(app_state)
      shiny::req(app_state$data$current_data)
      shiny::req(app_state$columns$mappings$y_column)

      # Get result regenerated with PDF export context (200x120mm @ 300 DPI)
      # This ensures correct label placement for high-res print output
      pdf_result <- pdf_export_plot()
      shiny::req(pdf_result, pdf_result$bfh_qic_result)

      # Titel og afdeling er isoleret -- de trigger allerede pdf_export_plot()
      # via dens egne reactive dependencies (debounced 1000ms).
      title_input <- shiny::isolate(input$export_title)
      dept_input <- shiny::isolate(input$export_department)
      # Analyse, datadefinition og hospital er debounced reactives (1000ms)
      # saa preview opdateres naar brugeren stopper med at skrive
      analysis_input <- debounced_analysis()
      data_def_input <- debounced_data_def()
      hospital_input <- debounced_hospital()

      # Build metadata for PDF generation
      # Bemaerk: bfh_create_typst_document() (preview-vejen) auto-genererer ikke
      # details -- det goer kun bfh_export_pdf(). Vi saetter derfor selv details
      # via BFHcharts::bfh_generate_details() saa preview matcher eksport.
      metadata <- list(
        hospital = if (nzchar(hospital_input)) hospital_input else get_hospital_name_for_export(),
        department = dept_input,
        title = title_input,
        analysis = analysis_input,
        details = safe_operation(
          operation_name = "Generate PDF preview details",
          code = BFHcharts::bfh_generate_details(pdf_result$bfh_qic_result),
          fallback = NULL,
          error_type = "processing"
        ),
        data_definition = data_def_input,
        author = Sys.getenv("USER"),
        date = Sys.Date()
      )

      # Generate PDF preview PNG using BFHcharts.
      # NOTE: Synkront kald -- withProgress giver UX-feedback men blokerer
      # stadig Shiny-sessionen. Fuld async (future-backend) er deferred --
      # se tasks.md Task 4 for begrundelse.
      safe_operation(
        operation_name = "Generate PDF preview PNG",
        code = {
          preview_path <- shiny::withProgress(
            message = "Genererer preview...",
            value = 0.5,
            {
              generate_pdf_preview(
                bfh_qic_result = pdf_result$bfh_qic_result,
                metadata = metadata,
                dpi = 150
              )
            }
          )

          log_debug(
            .context = "EXPORT_MODULE",
            message = "PDF preview PNG generated",
            details = list(
              preview_path = preview_path,
              has_preview = !is.null(preview_path)
            )
          )

          # NOTE: Don't use return() inside safe_operation code blocks!
          preview_path
        },
        fallback = function(e) {
          log_error(
            .context = "EXPORT_MODULE",
            message = "Failed to generate PDF preview PNG",
            details = list(error = e$message)
          )
          NULL
        },
        error_type = "processing"
      )
    }) |> shiny::debounce(millis = 1000) # Debounce for performance (PDF generation is slow)

    # PDF preview renderImage - displays PNG preview of Typst PDF layout
    output$pdf_preview <- shiny::renderImage(
      {
        preview_path <- pdf_preview_image()

        if (is.null(preview_path) || !file.exists(preview_path)) {
          # Return placeholder image (1x1 transparent PNG)
          return(list(
            src = "",
            contentType = "image/png",
            width = "100%",
            height = "auto",
            alt = "PDF preview ikke tilg\u00e6ngelig"
          ))
        }

        # Return PNG preview
        return(list(
          src = preview_path,
          contentType = "image/png",
          width = "100%",
          height = "auto",
          alt = "PDF layout preview"
        ))
      },
      deleteFile = FALSE # Don't delete temp file (will be cleaned up by R session)
    )

    # Lazy PDF preview: kun genberegn naar brugeren er paa eksport-fanen.
    # (Tidligere suspendWhenHidden = FALSE -- se commit c4c0a5d for rollback)
    outputOptions(output, "pdf_preview", suspendWhenHidden = TRUE)

    # PDF format flag - for conditional UI rendering
    output$is_pdf_format <- shiny::reactive({
      format <- input$export_format %||% "pdf"
      format == "pdf"
    })
    outputOptions(output, "is_pdf_format", suspendWhenHidden = FALSE)

    # === REGISTER SUB-MODULE OBSERVERS ======================================
    # Placeret efter reactive-definitioner for at undgaa forward references

    # Analysis auto-generation (mod_export_analysis.R)
    register_analysis_autogen(session, input, output, export_plot, app_state)

    # AI suggestion integration (mod_export_ai.R)
    register_ai_button_state(session, input, output, app_state)
    register_ai_suggestion_handler(session, input, output, app_state)

    # Download handlers (mod_export_download.R)
    register_export_downloads(output, input, session, app_state)

    # Return values -----------------------------------------------------------
    # Return module status for parent scope
    list(
      preview_ready = shiny::reactive({
        result <- export_plot()
        !is.null(result) && !is.null(result$plot)
      })
    )
  })
}
