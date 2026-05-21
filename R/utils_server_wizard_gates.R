# ==============================================================================
# utils_server_wizard_gates.R
# ==============================================================================
# WIZARD NAVIGATION GATE MANAGEMENT
#
# Extracted from: utils_server_event_listeners.R (Phase 2d refactoring)
# ==============================================================================

# Wizard step-besked-helpers indkapsler JS custom-message-strenge.
# Stavefejl i magic-string ville producere silent JS-fejl; helpers giver
# autocomplete + enkelt soegemaal hvis message-strenge skal aendres.

#' Wizard step-besked-helpers
#'
#' Send JS custom-message til klient for at lock/unlock/complete/uncomplete
#' et wizard-trin. Strengene matcher handlers i `inst/app/www/wizard-nav.js`.
#'
#' @param session Shiny session
#' @param step Integer wizard-trin (1-3)
#' @keywords internal
#' @name wizard_step_messages
NULL

#' @rdname wizard_step_messages
#' @keywords internal
wizard_lock_step <- function(session, step) {
  session$sendCustomMessage("wizard-lock-step", step)
}

#' @rdname wizard_step_messages
#' @keywords internal
wizard_unlock_step <- function(session, step) {
  session$sendCustomMessage("wizard-unlock-step", step)
}

#' @rdname wizard_step_messages
#' @keywords internal
wizard_complete_step <- function(session, step) {
  session$sendCustomMessage("wizard-complete-step", step)
}

#' @rdname wizard_step_messages
#' @keywords internal
wizard_uncomplete_step <- function(session, step) {
  session$sendCustomMessage("wizard-uncomplete-step", step)
}

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
  wizard_lock_step(session, 2)
  wizard_lock_step(session, 3)

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
        wizard_complete_step(session, 1)
        wizard_unlock_step(session, 2)
        # Skip auto-navigation under session restore: restore-observer har
        # allerede valgt korrekt tab (saved_tab), og vi maa ikke overskrive
        # brugerens gemte valg med default "analyser". Issue #193.
        if (!is_restoring_session(app_state)) {
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
        wizard_lock_step(session, 2)
        wizard_lock_step(session, 3)
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
      wizard_complete_step(session, 2)
      wizard_unlock_step(session, 3)
      shinyjs::enable("continue_to_export")
    } else {
      # Kun send lock-beskeder naar plot_ready eksplicit er FALSE (ej NULL ved init)
      req(!is.null(plot_ready))
      wizard_uncomplete_step(session, 2)
      wizard_lock_step(session, 3)
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

  # Gem til fil: download handler (delt logik mellem trin 2 og trin 3).
  # Helper-funktioner findes i utils_server_spc_save.R og deles med
  # navigation-guard-modal saa begge call-sites producerer identisk
  # 3-ark Excel-fil plus samme titel-baserede filnavn.
  spc_save_filename_handler <- function() {
    spc_save_filename(app_state, input)
  }

  spc_save_content_handler <- function(file) {
    safe_operation(
      "Gem til fil",
      code = {
        build_spc_excel_full(app_state, input, file = file)
      },
      error_type = "processing",
      session = session,
      show_user = TRUE
    )
  }

  output$download_spc_file <- shiny::downloadHandler(
    filename = spc_save_filename_handler,
    content = spc_save_content_handler
  )
  output$download_spc_file_step3 <- shiny::downloadHandler(
    filename = spc_save_filename_handler,
    content = spc_save_content_handler
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
