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
#' @param emit Event emission API
#' @keywords internal
setup_wizard_gates <- function(input, output, app_state, session, emit) {
  # Lock trin 2+3 ved startup
  session$sendCustomMessage("wizard-lock-step", 2)
  session$sendCustomMessage("wizard-lock-step", 3)

  # Gate: Data loaded -> unlock trin 2, auto-naviger
  shiny::observeEvent(app_state$events$data_updated,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$UI_SYNC,
    {
      # Skip hele body under nav-guard confirm-flow: handle_nav_guard_confirm
      # styrer selv wizard-step-messages + nav_select, og denne observer ville
      # ellers nav_select("analyser") og overskrive target.
      if (get_guard_active(app_state)) {
        log_info(
          "wizard_gates: skipper data_updated handler (guard_active = TRUE)",
          .context = "NAV_GUARD"
        )
        return(invisible(NULL))
      }
      # has_real_data() ekskluderer placeholder-data (20 NA-raekker fra
      # create_empty_session_data) saa wizard ikke auto-navigerer til
      # trin 2 paa fresh blank session.
      has_data <- has_real_data(app_state)
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
  # priority = UI_SYNC (750): korer efter state-opdateringer, undgaar dobbelt-
  # trigger naar plot_ready flippes FALSE->TRUE i samme reactive cyklus.
  shiny::observe(priority = OBSERVER_PRIORITIES$UI_SYNC, {
    plot_ready <- app_state$visualization$plot_ready
    if (isTRUE(plot_ready)) {
      session$sendCustomMessage("wizard-complete-step", 2)
      session$sendCustomMessage("wizard-unlock-step", 3)
      shinyjs::enable("continue_to_export")
    } else {
      # Kun send lock-beskeder naar plot_ready eksplicit er FALSE (ej NULL ved init)
      req(!is.null(plot_ready))
      session$sendCustomMessage("wizard-uncomplete-step", 2)
      session$sendCustomMessage("wizard-lock-step", 3)
      shinyjs::disable("continue_to_export")
    }
  })

  # Gem-knap: aktiv naar data er uploadet (trin 2 og trin 3)
  # priority = UI_SYNC (750): korer efter state-opdateringer
  shiny::observe(priority = OBSERVER_PRIORITIES$UI_SYNC, {
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
    if (is.null(title) || !nzchar(trimws(title))) {
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

        # Cycle C H1 (Codex 2026-05-10): ekstraher freeze_position fra data
        # + metadata$frys_column saa SPC-analyse-arket Sektion A 'Frozen til
        # raekke' populeres per spec. extract_freeze_position returnerer NULL
        # hvis ingen frys_column eller ingen markeringer findes — gracefully
        # haandteret af build_spc_analysis_sheet.
        # NB: phase_names er IKKE sat (Codex anbefaling): qic_data$part er
        # auto-genereret integer-IDs, ej user-labels. Implementer kun naar
        # eksplicit label-source-kontrakt eksisterer.
        freeze_position <- tryCatch(
          extract_freeze_position(data, metadata$frys_column),
          error = function(e) NULL # nolint: swallowed_error_linter
        )

        analysis_options <- list(
          pkg_versions = list(
            biSPCharts = tryCatch(as.character(utils::packageVersion("biSPCharts")),
              error = function(e) ""
            ),
            BFHcharts = tryCatch(as.character(utils::packageVersion("BFHcharts")),
              error = function(e) ""
            )
          ),
          computed_at = Sys.time(),
          freeze_position = freeze_position
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

  # Tilbage-knap: Trin 2 -> Trin 1 (via navigation guard)
  shiny::observeEvent(input$back_to_upload,
    priority = OBSERVER_PRIORITIES$STATUS_UPDATES,
    {
      emit$navigation_requested("upload")
    }
  )

  # Fortsaet-knap: Trin 2 -> Trin 3 (kun hvis plot er klar)
  shiny::observeEvent(input$continue_to_export,
    priority = OBSERVER_PRIORITIES$STATUS_UPDATES,
    {
      if (!isTRUE(shiny::isolate(app_state$visualization$plot_ready))) {
        shiny::showNotification(
          "V\u00e6lg kolonner og generer et diagram f\u00f8rst",
          type = "warning", duration = 3
        )
        return()
      }
      bslib::nav_select("main_navbar", selected = "eksporter", session = session)
    }
  )
}

#' Setup observers for paste data og sample data loading
#'
#' @param input Shiny input
#' @param app_state Centraliseret app state
#' @param session Shiny session
#' @param emit Event emit API
