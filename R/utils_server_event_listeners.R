# ==============================================================================
# utils_server_event_listeners.R
# ==============================================================================
# MAIN ORCHESTRATOR FOR EVENT SYSTEM
#
# Purpose: Coordinate initialization and registration of all event listeners.
#          Acts as the single entry point for the unified reactive event system.
#
# Architecture Pattern:
#   setup_event_listeners() orchestrates registration of all event categories:
#   1. Data lifecycle events (utils_server_events_data.R)
#   2. Auto-detection events (utils_server_events_autodetect.R)
#   3. UI synchronization events (utils_server_events_ui.R)
#   4. Navigation and session lifecycle (utils_server_events_navigation.R)
#   5. Chart type and column selection (utils_server_events_chart.R)
#   6. Wizard navigation gates (utils_server_wizard_gates.R)
#   7. Paste data handlers (utils_server_paste_data.R)
#
# Phase 2d Refactoring: Split from 1791 LOC monolith into focused modules.
# Event ordering and observer priorities preserved from original implementation.
#
# @name utils_event_system
NULL

#' Setup Event Listeners
#'
#' Main orchestrator for the unified reactive event system.
#' Registers all event categories via modular helper functions.
#'
#' @param app_state Centralized app state
#' @param emit Event emission API
#' @param input Shiny input
#' @param output Shiny output
#' @param session Shiny session
#' @param ui_service UI service for UI updates (optional)
#'
#' @return Invisible observer registry (for testing/debugging)
#' @keywords internal
setup_event_listeners <- function(app_state, emit, input, output, session, ui_service = NULL) {
  # DUPLICATE PREVENTION: Check if optimized listeners are already active
  if (exists("optimized_listeners_active", envir = app_state) && app_state$optimized_listeners_active) {
    stop("Cannot setup standard listeners while optimized listeners are active. This would cause duplicate execution.")
  }

  # Mark that standard listeners are active to prevent duplicate optimized listeners
  app_state$standard_listeners_active <- TRUE

  # Observer registry for cleanup on session end
  observer_registry <- list()

  # Helper function to register observers automatically.
  # Destruerer eksisterende observer ved navne-overwrite (#487) — ellers
  # forbliver gamle observers aktive i Shiny's reactive graph som "zombies"
  # (ej fanget af session-cleanup der kun rydder registry-indhold).
  register_observer <- function(name, observer) {
    existing <- observer_registry[[name]]
    if (!is.null(existing)) {
      tryCatch(
        if (!is.null(existing$destroy)) existing$destroy(),
        error = function(e) {
          log_warn(
            message = paste("Observer destroy fejlede ved overwrite for", name, ":", e$message),
            .context = "OBSERVER_MGMT"
          )
        }
      )
    }
    observer_registry[[name]] <<- observer
    observer
  }

  # ============================================================================
  # MODULAR EVENT REGISTRATION
  # ============================================================================

  observers <- list()

  # 1. Data lifecycle events (utils_server_events_data.R)
  data_observers <- register_data_lifecycle_events(
    app_state, emit, input, output, session, ui_service, register_observer
  )
  observers <- c(observers, data_observers)

  # 2. Auto-detection events (utils_server_events_autodetect.R)
  autodetect_observers <- register_autodetect_events(
    app_state, emit, session, register_observer
  )
  observers <- c(observers, autodetect_observers)

  # 3. UI synchronization events (utils_server_events_ui.R)
  ui_observers <- register_ui_sync_events(
    app_state, emit, input, output, session, ui_service, register_observer
  )
  observers <- c(observers, ui_observers)

  # 4. Navigation and session lifecycle (utils_server_events_navigation.R)
  navigation_observers <- register_navigation_events(
    app_state, emit, session, register_observer
  )
  observers <- c(observers, navigation_observers)

  # 5. Chart type and column selection (utils_server_events_chart.R)
  chart_observers <- register_chart_type_events(
    app_state, emit, input, session, register_observer
  )
  observers <- c(observers, chart_observers)

  # 6. Form events with ui_service
  if (!is.null(ui_service)) {
    register_observer(
      "form_reset_with_ui",
      shiny::observeEvent(app_state$events$form_reset_needed,
        ignoreInit = TRUE,
        priority = OBSERVER_PRIORITIES$LOW,
        {
          ui_service$reset_form_fields()
        }
      )
    )

    register_observer(
      "form_restore_with_ui",
      shiny::observeEvent(app_state$events$form_restore_needed,
        ignoreInit = TRUE,
        priority = OBSERVER_PRIORITIES$LOW,
        {
          if (!is.null(app_state$session$restore_metadata)) {
            ui_service$update_form_fields(app_state$session$restore_metadata)
          }
        }
      )
    )
  }

  # 7. Wizard navigation gates (utils_server_wizard_gates.R)
  setup_wizard_gates(input, output, app_state, session)

  # Issue #193: Bridge manuel tab-skift til event-bus
  register_observer(
    "main_navbar_manual",
    shiny::observeEvent(input$main_navbar,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$STATUS_UPDATES,
      {
        emit$navigation_changed()
      }
    )
  )

  # 8. Paste data og sample data observers (utils_server_paste_data.R)
  setup_paste_data_observers(input, output, app_state, session, emit, ui_service)

  # ============================================================================
  # OBSERVER CLEANUP ON SESSION END
  # ============================================================================
  session$onSessionEnded(function() {
    safe_operation(
      "Observer cleanup on session end",
      code = {
        observer_count <- length(observer_registry)
        failed_observers <- character(0)

        log_debug(
          paste("Cleaning up", observer_count, "observers"),
          .context = "EVENT_SYSTEM"
        )

        for (observer_name in names(observer_registry)) {
          tryCatch(
            {
              if (!is.null(observer_registry[[observer_name]])) {
                observer_registry[[observer_name]]$destroy()
                observer_registry[[observer_name]] <- NULL
              }
            },
            error = function(e) {
              failed_observers <<- c(failed_observers, observer_name)
              log_warn(
                paste("Failed to destroy observer:", observer_name, "-", e$message),
                .context = "EVENT_SYSTEM"
              )
            }
          )
        }

        successful_count <- observer_count - length(failed_observers)

        if (length(failed_observers) > 0) {
          log_warn(
            paste("Observer cleanup incomplete:", length(failed_observers), "failed"),
            .context = "EVENT_SYSTEM"
          )
        } else {
          log_info(
            paste("Observer cleanup complete: All", observer_count, "observers destroyed"),
            .context = "EVENT_SYSTEM"
          )
        }
      },
      fallback = function(e) {
        log_error(
          paste("Observer cleanup failed:", e$message),
          .context = "EVENT_SYSTEM"
        )
      }
    )
  })

  invisible(observer_registry)
}
