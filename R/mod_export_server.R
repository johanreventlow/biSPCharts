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
    shiny::observeEvent(input$back_to_analysis,
      ignoreNULL = TRUE,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$STATUS_UPDATES,
      {
        if (!is.null(parent_session)) {
          bslib::nav_select("main_navbar", selected = "analyser", session = parent_session)
        }
      }
    )

    # PREVIEW GENERATION ======================================================

    # METADATA-INPUT-DEBOUNCE (#646) ==========================================
    # Debounce title + department paa input-niveau (1500ms). Tidligere blev
    # hele export_plot/pdf_export_plot debounced med 500/1000ms, men det
    # ramte ogsaa png_width/png_height-skift (spinner-klik). Per-input-debounce
    # adskiller cosmetic-typing (slow debounce) fra dimension-skift (snappy).
    debounced_title <- shiny::debounce(
      shiny::reactive(input$export_title %||% ""),
      millis = DEBOUNCE_DELAYS$metadata_input
    )
    debounced_dept <- shiny::debounce(
      shiny::reactive(input$export_department %||% ""),
      millis = DEBOUNCE_DELAYS$metadata_input
    )
    # #EM1 (Codex 2026-05-08): debounced_footnote bruges af baade PNG-preview
    # (output$export_preview) og PDF-preview (pdf_preview_image). Flyttet op
    # i scope saa PNG-renderPlot ikke laeser input$export_footnote direkte
    # (per-keystroke re-render) men i stedet venter paa debounced reactive.
    debounced_footnote <- shiny::debounce(
      shiny::reactive(input$export_footnote %||% ""),
      millis = DEBOUNCE_DELAYS$metadata_input
    )

    # Export plot reactive - regenerates plot with export-specific dimensions
    # Issue #61: Separate plot generation with context "export_preview" (800x450px)
    # Issue #62: Cache isolated from analysis context
    # Issue #646: title/dept debounced paa input-niveau (1500ms) -- png_width/
    # png_height passerer reactive uden delay for snappy spinner-respons.
    export_plot <- shiny::reactive({
      # TAB-GUARD (Issue #644): hejs guard fra renderPlot til selve reactive.
      # Tidligere fyrede export_plot paa fremmed tab fordi register_analysis_autogen
      # observerede reactive paa tvaers af tab-skift. Reactive-niveau-guard
      # eliminerer Typst-render + BFH-compute paa upload/analyser-tab.
      shiny::req(app_state$session$active_tab == "eksporter")

      chart_type <- resolve_export_chart_type(app_state)

      # Single req() call for all required dependencies.
      # NB: x_column er IKKE i req() -- den maa vaere NULL (auto-detect kunne
      # ikke gaette x, fx ved faa raekker eller tekst-x uden dato-format).
      # build_export_plot tolererer NULL x og generateSPCPlot fallback'er til
      # spc_row_index (samme som analyse-pathen). Tidligere blokerede req()
      # paa NULL x_column og preview blev aldrig rendret -- selvom analyse-
      # fanen viste fungerende chart. Se R/utils_export_helpers.R og NEWS.
      shiny::req(
        app_state,
        app_state$data$current_data,
        app_state$columns$mappings$y_column,
        chart_type,
        nzchar(trimws(chart_type))
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

      # Read DEBOUNCED metadata inputs (#646)
      title_input <- debounced_title()
      dept_input <- debounced_dept()

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
    })

    # PDF EXPORT PLOT GENERATION ==============================================

    # PDF export reactive - regenerates plot with PDF-specific dimensions
    # This ensures correct label placement for high-res print output
    # (200x120mm @ 300 DPI = ~2362x1417px)
    # Issue #65: Use shared helper to reduce code duplication
    # Issue #646: Title/dept debounced paa input-niveau via debounced_title/dept
    pdf_export_plot <- shiny::reactive({
      # TAB-GUARD (Issue #644): kun beregn pdf_export_plot paa eksporter-tab.
      shiny::req(app_state$session$active_tab == "eksporter")

      # NB: x_column ej i req() -- se kommentar i export_plot reactive ovenfor.
      shiny::req(
        app_state,
        app_state$data$current_data,
        app_state$columns$mappings$y_column
      )

      # Read DEBOUNCED metadata inputs (#646)
      title_input <- debounced_title()
      dept_input <- debounced_dept()

      # Issue #65: Use shared helper with "export_pdf" context
      build_export_plot(app_state, title_input, dept_input, "export_pdf")
    })

    # EXPORT PREVIEW RENDERING ================================================

    # Export preview renderPlot - displays plot with export metadata
    # Note: BFHcharts already applies hospital theme automatically via BFHtheme::theme_bfh()
    output$export_preview <- shiny::renderPlot(
      {
        # Guard: kun render paa eksporter-tab. suspendWhenHidden=TRUE (linje 224)
        # hjaelper, men bs4Dash-navbar registrerer ej output som hidden i Shiny core.
        # Eksplicit req() via app_state$session$active_tab sikrer korrekt gating
        # og skaber reaktiv dependency saa render genoptages naar brugeren navigerer
        # til eksporter-tab (Issue #407).
        shiny::req(app_state$session$active_tab == "eksporter")

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

        # Tilfoej subtitle (hospital + afdeling) og margin til PNG preview.
        # #EM1 (Codex 2026-05-08): laes debounced reactives i stedet for
        # input$ direkte. Tidligere udloeste hver keystroke i department/
        # footnote en fuld renderPlot-cyklus (~100ms). Nu venter renderPlot
        # paa metadata_input-debounce (1500ms) som dept/title.
        plot <- spc_result$plot

        dept_text <- trimws(debounced_dept())
        if (nchar(dept_text) > 0) {
          plot <- plot + ggplot2::labs(subtitle = dept_text)
        }

        footnote_text <- trimws(debounced_footnote())
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
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$UI_SYNC
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
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$UI_SYNC
    )

    # PDF PREVIEW GENERATION ==================================================

    # PDF preview reactive - generates PNG preview of Typst PDF layout
    # Only active when format is "pdf"
    # Debounced metadata-inputs til PDF preview (undgaar re-render per tastetryk)
    # Issue #646: hejs debounce 1000 -> 1500ms for at absorbere flere keystrokes
    # i lange tekst-felter. Behold separate reactives for at undgaa unoedig
    # kobling i pdf-preview-cascade.
    debounced_analysis <- shiny::debounce(
      shiny::reactive(input$pdf_improvement %||% ""),
      millis = DEBOUNCE_DELAYS$metadata_input
    )
    debounced_data_def <- shiny::debounce(
      shiny::reactive(input$pdf_description %||% ""),
      millis = DEBOUNCE_DELAYS$metadata_input
    )
    debounced_hospital <- shiny::debounce(
      shiny::reactive(input$export_hospital %||% ""),
      millis = DEBOUNCE_DELAYS$metadata_input
    )
    # NOTE: debounced_footnote er flyttet til top-of-server-scope (#EM1) saa
    # PNG-preview kan dele samme debouncer. Definition: se efter debounced_dept.

    # ADR-004 exception: effective_analysis_val er session-scoped reactiveVal
    # -- bevidst konstrueret udenfor app_state-hierarkiet fordi diff-check-
    # idiom kraever Shiny 1.13.0 identical()-semantik paa reactiveVal$set()
    # (skip-invalidation hvis old===new). app_state-fields er hierarkiske
    # reactiveValues; identical-check sker kun mod containerens last-set,
    # ej per-field. Cycle 12 H1, PR #759.
    #
    # reactiveVal-diff-check eliminerer redundant 2. preview-render i
    # foerste-tab-besoeg. Mekanik:
    #   - Observer laeser debounced_analysis() + last_auto_analysis
    #   - Beregner effective text via compute_effective_analysis_text()
    #   - Skipper reactiveVal-update hvis identical med eksisterende (Shiny
    #     1.13.0 source: reactiveVal$set() returnerer FOER invalidation
    #     hvis identical(old, new))
    #   - pdf_preview_image laeser effective_analysis_val() -- invalideres
    #     KUN ved reel value-change, ej ved no-op dep-invalidation
    #
    # PRIORITY ORDERING (Codex Shiny flush-simulation): Observer SKAL have
    # eksplicit priority > 0 for at fyre FOER outputs (default priority 0).
    # Priority PLOT_GENERATION (600) er mellem autogen (UI_SYNC=750) og
    # default outputs -- garanterer:
    #   - EFTER autogen-observer (sat last_auto_analysis)
    #   - FOER output-rendering (sikrer effective_analysis_val populated)
    # Uden eksplicit priority ville priority-0 race med outputs reproducere
    # cycle 11 H1 i ny form (tom 1. render -> fuld 2. render).
    effective_analysis_val <- shiny::reactiveVal(
      shiny::isolate(app_state$ui$last_auto_analysis %||% "")
    )
    shiny::observe(
      {
        new_text <- compute_effective_analysis_text(
          user_text = debounced_analysis(),
          auto_text = app_state$ui$last_auto_analysis %||% ""
        )
        current <- shiny::isolate(effective_analysis_val())
        if (!identical(new_text, current)) {
          effective_analysis_val(new_text)
        }
      },
      priority = OBSERVER_PRIORITIES$PLOT_GENERATION
    )

    pdf_preview_image <- shiny::reactive({
      # TAB-GUARD (Issue #644): Typst->PNG-render er dyr (~2s) og maa ej koere
      # mens brugeren er paa upload/analyser-tab. Tidligere lakage skyldtes at
      # output$pdf_preview kun tab-guardede output-niveauet, ikke reactive-bodyen.
      shiny::req(app_state$session$active_tab == "eksporter")

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
      # Cycle 12 H1 (2026-05-16 sen): Laes effective-analysis fra reactiveVal
      # der kun invalideres ved reel value-change. Eliminerer redundant 2.
      # render naar debounced_analysis ankommer fra klient-roundtrip med
      # vaerdi der matcher allerede-vist auto_text.
      #
      # Historisk: Cycle 11 H1 (PR #753) introducerede
      # compute_effective_analysis_text() inline-kald som fix paa "preview
      # render med tom tekst foer autogen-text ankom". Det loeste 1. render
      # men efterlod 2. render som no-op redundans. Cycle 12 wrapper i
      # reactiveVal med diff-check eliminerer 2. render via Shiny's
      # built-in identical-skip-invalidation-semantik.
      analysis_input <- effective_analysis_val()
      data_def_input <- debounced_data_def()
      hospital_input <- debounced_hospital()
      footnote_input <- trimws(debounced_footnote())

      # Build metadata for PDF generation.
      # Bemaerk: bfh_create_typst_document() (preview-vejen) auto-genererer ikke
      # details -- det goer kun bfh_export_pdf(). Vi saetter derfor selv details
      # via BFHcharts::bfh_generate_details() saa preview matcher eksport.
      #
      # BFHcharts haandterer al Typst-escaping internt: escape_typst_string() for
      # plain-text-felter og markdown_to_typst() (AST-baseret) for rich-text-felter.
      # Pre-escape via escape_typst_metadata() er fjernet fordi den dobbelt-escaper
      # markdown-syntax (`**fed**` -> `\*\*fed\*\*`) saa BFHcharts AST-parseren ej
      # genkender bold/italic. Historisk (#427/#486) escapede vi selv da Typst-
      # template var lokal i biSPCharts; v0.3.0-migration (cc21b50c) flyttede
      # rendering til BFHcharts uden at fjerne pre-escape.
      preview_hospital_value <- if (nzchar(hospital_input)) {
        hospital_input
      } else {
        get_hospital_name_for_export()
      }
      # x_labels: original tekst-x-labels (maanedsnavne etc.) propageret via
      # standardized output fra fct_spc_execute.R. NULL ved numerisk x ->
      # bfh_generate_details falder tilbage til dato-baseret Periode-format.
      preview_x_labels <- pdf_result$x_labels
      metadata <- list(
        hospital = preview_hospital_value,
        department = dept_input,
        title = title_input,
        analysis = analysis_input,
        details = safe_operation(
          operation_name = "Generate PDF preview details",
          code = BFHcharts::bfh_generate_details(
            pdf_result$bfh_qic_result,
            x_labels = preview_x_labels
          ),
          fallback = NULL,
          error_type = "processing"
        ),
        data_definition = data_def_input,
        footer_content = if (nzchar(footnote_input)) footnote_input else NULL,
        date = Sys.Date()
      )

      # Generate PDF preview PNG using BFHcharts.
      # NOTE: Synkront kald -- withProgress giver UX-feedback men blokerer
      # stadig Shiny-sessionen. Fuld async (future-backend) er deferred --
      # se tasks.md Task 4 for begrundelse.
      safe_operation(
        operation_name = "Generate PDF preview PNG",
        code = {
          # Cycle E NEW1 (Codex 2026-05-10): brug session-scoped PNG-sti der
          # overskrives per render i stedet for tempfile() der akkumulerer.
          # Per Connect-long-session kan tempfile()-pattern lagre 100MB+ pga.
          # ~40 previews/min worst case under typing.
          session_preview_path <- file.path(
            tempdir(),
            paste0("bfh_preview_session_", session$token, ".png")
          )

          preview_path <- shiny::withProgress(
            message = "Genererer preview...",
            value = 0.5,
            {
              generate_pdf_preview(
                bfh_qic_result = pdf_result$bfh_qic_result,
                metadata = metadata,
                dpi = 150,
                preview_path = session_preview_path
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
    }) |> shiny::debounce(millis = DEBOUNCE_DELAYS$metadata_input) # #646: 1500ms -- Typst-render dyr, faerre cascades

    # PDF preview renderImage - displays PNG preview of Typst PDF layout
    output$pdf_preview <- shiny::renderImage(
      {
        # Guard: kun render paa eksporter-tab. Samme begrundelse som export_preview
        # -- bs4Dash registrerer ej output som hidden i Shiny core (Issue #407).
        shiny::req(app_state$session$active_tab == "eksporter")

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
    # #EH0 (Codex 2026-05-08): pass pdf_export_plot (PDF-context) i stedet for
    # export_plot (PNG-context). Auto-gen bruges kun paa PDF-mode (format-guard
    # i mod_export_analysis.R), og pdf_export_plot deler cache-key med
    # PDF-preview, saa observer-evaluering bliver cache-hit i stedet for ekstra
    # generateSPCPlot()-koersel.
    register_analysis_autogen(session, input, output, pdf_export_plot, app_state)

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
