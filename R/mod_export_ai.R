# ==============================================================================
# mod_export_ai.R
# ==============================================================================
# AI SUGGESTION INTEGRATION MODULE FOR EXPORT
#
# Purpose: Extract AI improvement suggestion logic from mod_export_server.R.
#          Manages BFHllm integration, button state, and AI-generated analysis.
#
# Extracted from: mod_export_server.R (Phase 2b refactoring)
# Depends on: app_state, session, input/output
# ==============================================================================

#' Register AI Button State Observer
#'
#' Sets up observer that manages AI suggestion button enabled/disabled state
#' based on data availability and API key setup.
#'
#' @param session Shiny session object
#' @param input Input object containing UI inputs
#' @param output Output object for rendering
#' @param app_state Global app state containing data and column mappings
#'
#' @return NULL (side effect: registers observer with Shiny)
#'
#' @keywords internal
register_ai_button_state <- function(session, input, output, app_state) {
  # Review fund #4: Cache BFHllm availability per session.
  # is_bfhllm_available() kalder BFHllm::bfhllm_chat_available() som
  # har log-sideeffekter ("BFHllm setup validated successfully") og evt.
  # netvaerksarbejde. API-noeglen aendrer sig ikke under session-levetid,
  # saa vi cacher resultatet en gang per session. Det fjerner stoej-loggen
  # uden at aendre funktionaliteten.
  bfhllm_available_cached <- NULL
  get_bfhllm_available <- function() {
    if (is.null(bfhllm_available_cached)) {
      bfhllm_available_cached <<- isTRUE(is_bfhllm_available())
    }
    bfhllm_available_cached
  }

  # Manage AI button state based on data and API key availability
  shiny::observe({
    # Check prerequisites
    has_data <- !is.null(app_state$data$current_data) &&
      nrow(app_state$data$current_data) > 0
    has_columns <- !is.null(app_state$columns$mappings$x_column) &&
      !is.null(app_state$columns$mappings$y_column)
    has_spc_data <- has_data && has_columns

    # Validate BFHllm API setup (cached per session)
    api_ready <- get_bfhllm_available()

    # Button enabled only when both prerequisites met
    can_use_ai <- has_spc_data && api_ready

    # Toggle button state
    shinyjs::toggleState("ai_generate_suggestion", can_use_ai)

    # Update tooltip based on state
    tooltip_js <- if (!has_spc_data) {
      sprintf(
        "$('#%s').attr('title', 'Gener\u00e9r f\u00f8rst en SPC-graf for at bruge AI-forslag');",
        session$ns("ai_generate_suggestion")
      )
    } else if (!api_ready) {
      sprintf(
        "$('#%s').attr('title', 'AI-funktionalitet kr\u00e6ver Google API-n\u00f8gle. Kontakt administrator.');",
        session$ns("ai_generate_suggestion")
      )
    } else {
      sprintf(
        "$('#%s').attr('title', 'Klik for at generere en analyse med AI');",
        session$ns("ai_generate_suggestion")
      )
    }

    shinyjs::runjs(tooltip_js)

    log_debug(
      .context = "EXPORT_MODULE",
      message = "AI button state updated",
      details = list(
        has_spc_data = has_spc_data,
        api_ready = api_ready,
        button_enabled = can_use_ai
      )
    )
  }) |> shiny::bindEvent(
    app_state$data$current_data,
    app_state$columns$mappings$x_column,
    app_state$columns$mappings$y_column
  )
}

#' Register AI Suggestion Handler (Async)
#'
#' Sets up event listener for AI suggestion button click.
#' Generates SPC plot, calls bfh_generate_analysis() via ExtendedTask
#' (asynkront) for at undgÃ¥ at blokere andre Shiny-sessions pÃ¥ Connect.
#'
#' Fallback til synkron eksekvering hvis ExtendedTask ikke er tilgÃ¦ngeligt
#' (shiny < 1.8.0 eller promises mangler).
#'
#' @param session Shiny session object
#' @param input Input object containing UI inputs
#' @param output Output object for rendering
#' @param app_state Global app state containing data and column mappings
#'
#' @return NULL (side effect: registers observer and ExtendedTask with Shiny)
#'
#' @keywords internal
register_ai_suggestion_handler <- function(session, input, output, app_state) {
  # ---- Asynkron AI-task -------------------------------------------------------
  # ExtendedTask kr\u00e6ver at blive oprettet \u00c9N gang per session (ikke inde i
  # observeEvent), og invoked ved hvert klik. Se shiny::ExtendedTask docs.
  ai_task <- make_ai_extended_task(
    session = session,
    get_spc_result = function() {
      build_export_plot(
        app_state = app_state,
        title_input = shiny::isolate(input$export_title %||% ""),
        dept_input = shiny::isolate(input$export_department %||% ""),
        plot_context = "export_pdf"
      )
    },
    get_analysis_metadata = function() {
      spc_result <- shiny::isolate(build_export_plot(
        app_state = app_state,
        title_input = input$export_title %||% "",
        dept_input = input$export_department %||% "",
        plot_context = "export_pdf"
      ))
      if (is.null(spc_result)) {
        return(NULL)
      }
      build_export_analysis_metadata(
        bfh_qic_result  = spc_result$bfh_qic_result,
        target_value    = normalize_mapping(shiny::isolate(app_state$columns$mappings$target_value)),
        target_text     = normalize_mapping(shiny::isolate(app_state$columns$mappings$target_text)),
        data_definition = shiny::isolate(input$pdf_description %||% ""),
        chart_title     = shiny::isolate(input$export_title %||% ""),
        department      = shiny::isolate(input$export_department %||% "")
      )
    }
  )

  # ---- Klik-handler -----------------------------------------------------------
  shiny::observeEvent(input$ai_generate_suggestion,
    {
      # Valider foruds\u00e6tninger
      shiny::req(
        app_state$data$current_data,
        app_state$columns$mappings$x_column,
        app_state$columns$mappings$y_column
      )

      # Disable button og vis spinner
      shinyjs::disable("ai_generate_suggestion")
      output$ai_loading_feedback <- shiny::renderUI({
        shiny::div(
          class = "text-muted",
          style = "margin-top: 5px;",
          shiny::icon("spinner", class = "fa-spin"),
          " Genererer analyse..."
        )
      })

      log_info(
        .context = "EXPORT_MODULE",
        message  = "AI suggestion requested by user"
      )

      if (!is.null(ai_task)) {
        # ---- Asynkron sti: ExtendedTask ----------------------------------------
        # SPC-result bygges synkront (cache), AI-kaldet k\u00f8rer i baggrunden.
        spc_result <- build_export_plot(
          app_state = app_state,
          title_input = input$export_title %||% "",
          dept_input = input$export_department %||% "",
          plot_context = "export_pdf"
        )

        if (is.null(spc_result) || is.null(spc_result$bfh_qic_result)) {
          log_error(
            .context = "EXPORT_MODULE",
            message = "SPC result generation failed (async path)"
          )
          shiny::showNotification(
            "Kunne ikke analysere SPC-data. Pr\u00f8v igen.",
            type = "error", duration = 5
          )
          shinyjs::enable("ai_generate_suggestion")
          output$ai_loading_feedback <- shiny::renderUI(NULL)
          return()
        }

        ai_task$invoke()
      } else {
        # ---- Synkron fallback (shiny < 1.8.0 eller promises mangler) ----------
        spc_result <- build_export_plot(
          app_state = app_state,
          title_input = input$export_title %||% "",
          dept_input = input$export_department %||% "",
          plot_context = "export_pdf"
        )

        if (is.null(spc_result) || is.null(spc_result$bfh_qic_result)) {
          log_error(
            .context = "EXPORT_MODULE",
            message = "SPC result generation failed (sync fallback)"
          )
          shiny::showNotification(
            "Kunne ikke analysere SPC-data. Pr\u00f8v igen.",
            type = "error", duration = 5
          )
          shinyjs::enable("ai_generate_suggestion")
          output$ai_loading_feedback <- shiny::renderUI(NULL)
          return()
        }

        analysis_metadata <- build_export_analysis_metadata(
          bfh_qic_result  = spc_result$bfh_qic_result,
          target_value    = normalize_mapping(app_state$columns$mappings$target_value),
          target_text     = normalize_mapping(app_state$columns$mappings$target_text),
          data_definition = input$pdf_description %||% "",
          chart_title     = input$export_title %||% "",
          department      = input$export_department %||% ""
        )

        suggestion <- safe_operation(
          operation_name = "AI analysis generation (sync fallback)",
          code = {
            BFHcharts::bfh_generate_analysis(
              spc_result$bfh_qic_result,
              metadata  = analysis_metadata,
              use_ai    = TRUE,
              max_chars = 375L
            )
          },
          fallback = NULL,
          error_type = "processing"
        )

        handle_ai_suggestion_result(suggestion, session, output)
        shinyjs::enable("ai_generate_suggestion")
        output$ai_loading_feedback <- shiny::renderUI(NULL)
      }
    },
    priority = OBSERVER_PRIORITIES$HIGH
  )

  # ---- Observer for ExtendedTask-resultat -------------------------------------
  # Aktiveres n\u00e5r ai_task fuldf\u00f8res (succes eller fejl)
  if (!is.null(ai_task)) {
    shiny::observeEvent(
      ai_task$result(),
      ignoreInit = TRUE,
      {
        suggestion <- ai_task$result()

        # Tjek for fejlstruktur returneret af wrap_blocking_call
        if (inherits(suggestion, "ai_task_error")) {
          log_warn(
            .context = "EXPORT_MODULE",
            message  = paste("AI task fejlede:", suggestion$error)
          )
          suggestion <- NULL
        }

        handle_ai_suggestion_result(suggestion, session, output)
        shinyjs::enable("ai_generate_suggestion")
        output$ai_loading_feedback <- shiny::renderUI(NULL)
      }
    )
  }
}

#' HÃ¥ndter AI Suggestion Resultat (intern hjÃ¦lper)
#'
#' Opdaterer UI baseret pÃ¥ AI-suggestion-resultatet.
#' Adskilt fra handler for testbarhed og genbrug (async + sync sti).
#'
#' @param suggestion Character string med suggestion, eller NULL ved fejl
#' @param session Shiny session object
#' @param output Shiny output object
#' @keywords internal
handle_ai_suggestion_result <- function(suggestion, session, output) {
  if (!is.null(suggestion)) {
    shiny::updateTextAreaInput(session, "pdf_improvement", value = suggestion)
    shiny::showNotification(
      "\u2713 Analyse genereret. Du kan nu redigere teksten efter behov.",
      type = "message", duration = 3
    )
    log_info(
      .context = "EXPORT_MODULE",
      message  = "AI suggestion inserted",
      details  = list(length = nchar(suggestion))
    )
  } else {
    shiny::showNotification(
      "Kunne ikke generere AI-analyse. Tjek internetforbindelse og pr\u00f8v igen, eller skriv analysen manuelt.",
      type = "error", duration = 8
    )
    log_warn(
      .context = "EXPORT_MODULE",
      message  = "AI suggestion generation failed"
    )
  }
}
