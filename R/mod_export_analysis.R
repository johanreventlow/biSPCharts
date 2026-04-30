# ==============================================================================
# mod_export_analysis.R
# ==============================================================================
# ANALYSIS AUTO-GENERATION MODULE FOR EXPORT
#
# Purpose: Extract analysis auto-generation logic from mod_export_server.R.
#          Handles automatic text generation for PDF export with user edit detection.
#
# Extracted from: mod_export_server.R (Phase 2b refactoring)
# Depends on: export_plot reactive (from mod_export_server.R)
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
#' @param export_plot Reactive expression returning SPC plot result
#' @param app_state Reactive values object containing column mappings
#'
#' @return NULL (side effect: registers observers with Shiny)
#'
#' @keywords internal
register_analysis_autogen <- function(session, input, output, export_plot, app_state) {
  # Gem sidst auto-genererede tekst til sammenligning med brugerens input.
  # Undgår flaky analysis_source flag der fejlagtigt skifter til "user"
  # pga. Shiny flush-timing issues.
  last_auto_analysis <- shiny::reactiveVal("")

  # Auto-generer analysetekst når SPC-resultat er tilgængeligt.
  # Bruger observe() (ikke observeEvent) saa tab-guard evalueres FØR
  # export_plot() -- observeEvent evaluerer altid trigger-udtrykket
  # hvilket kalder generateSPCPlot() som side-effekt (Issue #394).
  shiny::observe(
    {
      # TAB-GUARD (Issue #394): Afbryd straks hvis brugeren IKKE er paa
      # eksporter-tab. req() forhindrer at export_plot() evalueres paa
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

      result <- export_plot()
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
        department = shiny::isolate(input$export_department %||% "")
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
      prev_auto <- shiny::isolate(last_auto_analysis())
      user_has_edited <- nchar(trimws(current_text)) > 0 && current_text != prev_auto

      if (!user_has_edited) {
        last_auto_analysis(auto_text)
        # Sæt suspend-flag FØR updateTextAreaInput så settings_save ikke
        # gemmer den programmatiske input-ændring som en bruger-ændring.
        # onFlushed(once=TRUE) rydder flaget efter Shiny har flushet
        # updateTextAreaInput-beskeden til klienten.
        app_state$session$autogen_active <- TRUE
        session$onFlushed(function() {
          app_state$session$autogen_active <- FALSE
        }, once = TRUE)
        shiny::updateTextAreaInput(session, "pdf_improvement", value = auto_text)
      }
    },
    priority = OBSERVER_PRIORITIES$LOW
  )

  # Vis/skjul auto-indikator: synlig når feltets tekst matcher auto-teksten
  shiny::observe({
    current <- input$pdf_improvement %||% ""
    auto <- last_auto_analysis()
    is_auto <- nchar(auto) > 0 && current == auto
    shinyjs::toggle("analysis_auto_indicator", condition = is_auto)
  })
}
