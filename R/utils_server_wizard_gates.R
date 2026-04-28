# ==============================================================================
# utils_server_wizard_gates.R
# ==============================================================================
# WIZARD NAVIGATION GATE MANAGEMENT
#
# Extracted from: utils_server_event_listeners.R (Phase 2d refactoring)
# ==============================================================================

#' Setup wizard navigation gates
#'
#' Locks/unlocks navbar wizard steps based on app state.
#' Trin 1 (Upload) altid tilgaengelig. Trin 2 (Analyser) kraever data.
#' Trin 3 (Eksporter) kraever renderet plot.
#'
#' @param input Shiny input
#' @param output Shiny output
#' @param app_state Centraliseret app state
#' @param session Shiny session
#' @keywords internal
setup_wizard_gates <- function(input, output, app_state, session) {
  # Lock trin 2+3 ved startup
  session$sendCustomMessage("wizard-lock-step", 2)
  session$sendCustomMessage("wizard-lock-step", 3)

  # Gate: Data loaded -> unlock trin 2, auto-naviger
  shiny::observeEvent(app_state$events$data_updated,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$UI_SYNC,
    {
      has_data <- !is.null(shiny::isolate(app_state$data$current_data))
      if (has_data) {
        session$sendCustomMessage("wizard-complete-step", 1)
        session$sendCustomMessage("wizard-unlock-step", 2)
        # Skip auto-navigation under session restore: restore-observer har
        # allerede valgt korrekt tab (saved_tab), og vi maa ikke overskrive
        # brugerens gemte valg med default "analyser". Issue #193.
        restoring <- isTRUE(shiny::isolate(app_state$session$restoring_session))
        if (!restoring) {
          bslib::nav_select(
            "main_navbar",
            selected = "analyser",
            session = session
          )
        } else {
          log_info(
            "wizard_gates: skipper auto-nav til analyser (restoring_session = TRUE)",
            .context = "SESSION_RESTORE"
          )
        }
      } else {
        session$sendCustomMessage("wizard-lock-step", 2)
        session$sendCustomMessage("wizard-lock-step", 3)
        bslib::nav_select(
          "main_navbar",
          selected = "upload",
          session = session
        )
      }
    }
  )

  # Gate: Plot renderet -> unlock trin 3, enable Fortsaet-knap
  shiny::observe({
    plot_ready <- app_state$visualization$plot_ready
    if (isTRUE(plot_ready)) {
      session$sendCustomMessage("wizard-complete-step", 2)
      session$sendCustomMessage("wizard-unlock-step", 3)
      shinyjs::enable("continue_to_export")
    } else {
      session$sendCustomMessage("wizard-uncomplete-step", 2)
      session$sendCustomMessage("wizard-lock-step", 3)
      shinyjs::disable("continue_to_export")
    }
  })

  # Gem-knap: aktiv naar data er uploadet (trin 2 og trin 3)
  shiny::observe({
    has_data <- isTRUE(app_state$session$file_uploaded) ||
      (!is.null(app_state$data$current_data) &&
        nrow(app_state$data$current_data) > 0)

    if (has_data) {
      shinyjs::enable("download_spc_file")
      shinyjs::enable("download_spc_file_step3")
    } else {
      shinyjs::disable("download_spc_file")
      shinyjs::disable("download_spc_file_step3")
    }
  })

  # Gem til fil: download handler (delt logik mellem trin 2 og trin 3)
  spc_save_filename <- function() {
    md <- collect_metadata(input, app_state)
    title <- md$indicator_title
    if (is.null(title) || nchar(trimws(title)) == 0) {
      return("data_biSPCharts.xlsx")
    }
    safe_title <- sanitize_filename(trimws(title))
    if (nchar(safe_title) == 0) {
      return("data_biSPCharts.xlsx")
    }
    safe_title <- stringr::str_trunc(safe_title, 50, ellipsis = "")
    paste0(safe_title, "_biSPCharts.xlsx")
  }

  spc_save_content <- function(file) {
    safe_operation(
      "Gem til fil",
      code = {
        data <- shiny::isolate(app_state$data$current_data)
        metadata <- collect_metadata(input, app_state)

        # Hent qic_data fra senest beregnede SPC-resultat. build_export_plot()
        # genererer plot + qic_data via samme pipeline som UI-grafen.
        # Hvis kaldet fejler eller returnerer NULL, springes SPC-analyse-arket
        # over (build_spc_excel() haandterer NULL graciously).
        qic_data <- NULL
        analysis_options <- list(
          pkg_versions = list(
            biSPCharts = tryCatch(as.character(utils::packageVersion("biSPCharts")),
              error = function(e) ""
            ),
            BFHcharts = tryCatch(as.character(utils::packageVersion("BFHcharts")),
              error = function(e) ""
            )
          ),
          computed_at = Sys.time()
        )
        spc_for_export <- tryCatch(
          build_export_plot(
            app_state = app_state,
            title_input = metadata$indicator_title %||% "",
            dept_input = metadata$export_department %||% "",
            plot_context = "export_pdf"
          ),
          error = function(e) {
            log_warn(
              .context = "EXCEL_EXPORT",
              message = paste(
                "build_export_plot fejlede ved Excel-download;",
                "SPC-analyse-ark springes over:", conditionMessage(e)
              )
            )
            NULL
          }
        )
        has_qic <- !is.null(spc_for_export) && is.list(spc_for_export) &&
          !is.null(spc_for_export$qic_data)
        if (has_qic) {
          qic_data <- spc_for_export$qic_data
        }

        temp_path <- build_spc_excel(
          data = data,
          metadata = metadata,
          qic_data = qic_data,
          original_data = data,
          analysis_options = analysis_options
        )
        on.exit(unlink(temp_path), add = TRUE)
        file.copy(temp_path, file)
      },
      error_type = "processing",
      session = session,
      show_user = TRUE
    )
  }

  output$download_spc_file <- shiny::downloadHandler(
    filename = spc_save_filename,
    content = spc_save_content
  )
  output$download_spc_file_step3 <- shiny::downloadHandler(
    filename = spc_save_filename,
    content = spc_save_content
  )

  # Tilbage-knap: Trin 2 -> Trin 1
  shiny::observeEvent(input$back_to_upload, {
    bslib::nav_select("main_navbar", selected = "upload", session = session)
  })

  # Fortsaet-knap: Trin 2 -> Trin 3 (kun hvis plot er klar)
  shiny::observeEvent(input$continue_to_export, {
    if (!isTRUE(shiny::isolate(app_state$visualization$plot_ready))) {
      shiny::showNotification(
        "V\u00e6lg kolonner og generer et diagram f\u00f8rst",
        type = "warning", duration = 3
      )
      return()
    }
    bslib::nav_select("main_navbar", selected = "eksporter", session = session)
  })
}

#' Setup observers for paste data og sample data loading
#'
#' @param input Shiny input
#' @param app_state Centraliseret app state
#' @param session Shiny session
#' @param emit Event emit API
