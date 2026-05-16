# ==============================================================================
# mod_export_analysis.R
# ==============================================================================
# ANALYSIS AUTO-GENERATION MODULE FOR EXPORT
#
# Purpose: Extract analysis auto-generation logic from mod_export_server.R.
#          Handles automatic text generation for PDF export with user edit detection.
#
# Extracted from: mod_export_server.R (Phase 2b refactoring)
# Depends on: pdf_export_plot reactive (from mod_export_server.R)
#            input$export_format, input$pdf_improvement, input$pdf_description
# ==============================================================================

#' Register Analysis Auto-Generation Observers
#'
#' Sets up observers for automatic analysis text generation when SPC results change.
#' Only generates for PDF format to avoid unnecessary re-renders for PNG.
#'
#' @param session Shiny session object
#' @param input Input object containing UI inputs
#' @param output Output object for rendering
#' @param pdf_export_plot Reactive expression returning PDF-context SPC plot
#'   result. Codex peer-review 2026-05-08 (#EH0): tidligere modtog observeren
#'   `export_plot` (PNG-context "export_preview") selv paa PDF-mode, hvilket
#'   trigger en uafhaengig generateSPCPlot()-koersel for PNG-context kun for
#'   at hente bfh_qic_result. Skift til pdf_export_plot eliminerer dobbelt-
#'   generering, da PDF-preview alligevel evaluerer samme reactive (cache-hit
#'   paa anden eval).
#' @param app_state Reactive values object containing column mappings
#'
#' @return NULL (side effect: registers observers with Shiny)
#'
#' @keywords internal
register_analysis_autogen <- function(session, input, output, pdf_export_plot, app_state) {
  # Sidst auto-genererede tekst læses/skrives via app_state$ui$last_auto_analysis
  # (migreret fra reactiveVal, ADR-004 — tracking-state hører i centralt app_state).

  # Auto-generer analysetekst når SPC-resultat er tilgængeligt.
  # Bruger observe() (ikke observeEvent) saa tab-guard evalueres FØR
  # pdf_export_plot() -- observeEvent evaluerer altid trigger-udtrykket
  # hvilket kalder generateSPCPlot() som side-effekt (Issue #394).
  shiny::observe(
    {
      # TAB-GUARD (Issue #394): Afbryd straks hvis brugeren IKKE er paa
      # eksporter-tab. req() forhindrer at pdf_export_plot() evalueres paa
      # andre tabs og sparer CPU + Typst PDF-render i baggrunden.
      shiny::req(app_state$session$active_tab == "eksporter")

      # FORMAT-GUARD: Auto-genereret analysetekst bruges KUN i PDF-eksport
      # (pdf_improvement-feltet). Naar formatet er png er analysen
      # irrelevant, og den resulterende updateTextAreaInput trigger en ny
      # preview-render uden reel brugeraendring.
      fmt <- input$export_format %||% "pdf"
      if (!identical(fmt, "pdf")) {
        return()
      }

      # #EH0 (Codex 2026-05-08): pdf_export_plot bruger context "export_pdf"
      # som matcher PDF-preview, saa observeren genbruger samme cache.
      # Tidligere kald til export_plot() (context "export_preview") forarsagede
      # parallel generateSPCPlot()-koersel udelukkende for at hente bfh_qic_result.
      result <- pdf_export_plot()
      if (is.null(result) || is.null(result$bfh_qic_result)) {
        return()
      }

      auto_metadata <- build_export_analysis_metadata(
        bfh_qic_result = result$bfh_qic_result,
        target_value = shiny::isolate(
          normalize_mapping(app_state$columns$mappings$target_value)
        ),
        target_text = shiny::isolate(
          normalize_mapping(app_state$columns$mappings$target_text)
        ),
        data_definition = shiny::isolate(input$pdf_description %||% ""),
        chart_title = shiny::isolate(input$export_title %||% ""),
        department = shiny::isolate(input$export_department %||% ""),
        footnote = shiny::isolate(input$export_footnote %||% "")
      )

      auto_text <- safe_operation(
        operation_name = "Auto-generate analysis text",
        code = {
          BFHcharts::bfh_generate_analysis(
            result$bfh_qic_result,
            metadata = auto_metadata,
            use_ai = FALSE
          )
        },
        error_type = "processing"
      )

      if (is.null(auto_text) || nchar(auto_text) == 0) {
        return()
      }

      # Opdatér kun hvis feltet er tomt eller indeholder den forrige auto-tekst
      current_text <- shiny::isolate(input$pdf_improvement) %||% ""
      prev_auto <- shiny::isolate(app_state$ui$last_auto_analysis)
      user_has_edited <- nzchar(trimws(current_text)) && current_text != prev_auto

      if (!user_has_edited) {
        # Cycle 11 H1 (Codex 2026-05-16): Saet server-state FOERST. Dette
        # eliminerer afhaengighed af klient-roundtrip for downstream-consumers
        # (pdf_preview_image bruger effective_analysis_text() der laeser
        # last_auto_analysis fra app_state — ej input$pdf_improvement).
        app_state$ui$last_auto_analysis <- auto_text

        # Cycle 11 H1: Skip updateTextAreaInput hvis feltets value allerede
        # matcher auto_text (fx tab-revisit med uaendret data). Tidligere
        # sendte vi altid besked til klient, hvilket forarsagede tom
        # roundtrip + debounced_analysis-invalidering => unoedig preview-
        # re-render.
        if (identical(current_text, auto_text)) {
          return()
        }

        # Saet suspend-flag FOER updateTextAreaInput saa settings_save ikke
        # gemmer den programmatiske input-aendring som en bruger-aendring.
        # onFlushed(once=TRUE) rydder flaget efter Shiny har flushet
        # updateTextAreaInput-beskeden til klienten.
        set_autogen_active(app_state, TRUE)
        session$onFlushed(function() {
          set_autogen_active(app_state, FALSE)
        }, once = TRUE)
        shiny::updateTextAreaInput(session, "pdf_improvement", value = auto_text)
      }
    },
    priority = OBSERVER_PRIORITIES$LOW
  )

  # Vis/skjul auto-indikator: synlig når feltets tekst matcher auto-teksten
  shiny::observe({
    current <- input$pdf_improvement %||% ""
    auto <- app_state$ui$last_auto_analysis
    is_auto <- nchar(auto) > 0 && current == auto
    shinyjs::toggle("analysis_auto_indicator", condition = is_auto)
  })
}
