# ==============================================================================
# utils_server_events_navigation.R
# ==============================================================================
# NAVIGATION AND SESSION LIFECYCLE EVENT HANDLERS
#
# Extracted from: utils_server_event_listeners.R (Phase 2d refactoring)
# ==============================================================================

#' Register Navigation Events
#'
#' Registers observers for navigation and session lifecycle.
#'
#' @param app_state Centralized app state
#' @param emit Event emission API
#' @param session Shiny session
#' @param register_observer Function to register observer for cleanup
#'
#' @return Named list of registered observers
#'
#' @details
#' Handles navigation, session lifecycle, test mode, and error events:
#' - navigation_changed: Increments navigation trigger
#' - session_started: Session initialization
#' - manual_autodetect_button: User-triggered detection
#' - session_reset: Complete state cleanup
#' - test_mode events: Test mode initialization and startup
#' - error events: Centralized error handling
#' - form events: UI field reset and restore
register_navigation_events <- function(app_state, emit, session, register_observer) {
  observers <- list()

  # Navigation changed
  observers$navigation_changed <- register_observer(
    "navigation_changed",
    shiny::observeEvent(app_state$events$navigation_changed,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$STATUS_UPDATES,
      {
        app_state$navigation$trigger <- app_state$navigation$trigger + 1L
      }
    )
  )

  # Session started
  observers$session_started <- register_observer(
    "session_started",
    shiny::observeEvent(app_state$events$session_started,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$AUTO_DETECT,
      {
        if (is.null(app_state$data$current_data) || nrow(app_state$data$current_data) == 0) {
          autodetect_engine(
            data = NULL,
            trigger_type = "session_start",
            app_state = app_state,
            emit = emit
          )
        } else {
          log_debug("Skipping session_started autodetect - data already available", .context = "AUTO_DETECT_EVENT")
        }
      }
    )
  )

  # Manual autodetect button
  observers$manual_autodetect_button <- register_observer(
    "manual_autodetect_button",
    shiny::observeEvent(app_state$events$manual_autodetect_button,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$AUTO_DETECT,
      {
        autodetect_engine(
          data = app_state$data$current_data,
          trigger_type = "manual",
          app_state = app_state,
          emit = emit
        )
      }
    )
  )

  # Session reset
  observers$session_reset <- register_observer(
    "session_reset",
    shiny::observeEvent(app_state$events$session_reset,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$CLEANUP,
      {
        # SPRINT 4: Clear QIC cache on session reset
        if (!is.null(app_state$cache) && !is.null(app_state$cache$qic)) {
          safe_operation(
            "Clear QIC cache on session reset",
            code = {
              app_state$cache$qic$clear()
              log_debug("QIC cache cleared due to session reset", .context = "QIC_CACHE")
            }
          )
        }

        # Clear all caches on session reset
        if (exists("clear_performance_cache") && is.function(clear_performance_cache)) {
          safe_operation(
            "Clear performance cache on session reset",
            code = {
              clear_performance_cache()
              log_debug("Performance cache cleared due to session reset", .context = "CACHE_INVALIDATION")
            }
          )
        }

        # Reset all state to initial values
        app_state$data$current_data <- NULL
        app_state$columns$auto_detect$in_progress <- FALSE
        app_state$columns$auto_detect$completed <- FALSE
        app_state$columns$auto_detect$results <- NULL
        app_state$columns$auto_detect$frozen_until_next_trigger <- FALSE
        app_state$columns$auto_detect$last_run <- NULL
      }
    )
  )

  # Test mode ready
  observers$test_mode_ready <- register_observer(
    "test_mode_ready",
    shiny::observeEvent(app_state$events$test_mode_ready,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$AUTO_DETECT,
      {
        if (exists("track_event")) {
          track_event("test_mode_ready", "startup_sequence")
        }

        app_state$test_mode$race_prevention_active <- TRUE
        emit$test_mode_startup_phase_changed("data_ready")

        autodetect_completed <- app_state$columns$auto_detect$completed %||% FALSE
        data_available <- !is.null(app_state$data$current_data)

        if (data_available && !autodetect_completed) {
          debounce_delay <- app_state$test_mode$debounce_delay %||% 500

          debounced_test_mode_trigger <- shiny::debounce(
            shiny::reactive({
              if (app_state$test_mode$race_prevention_active) {
                emit$test_mode_debounced_autodetect()
              }
            }),
            millis = debounce_delay
          )

          debounced_test_mode_trigger()
        } else if (autodetect_completed) {
          emit$ui_sync_needed()
        }
      }
    )
  )

  # Test mode startup phase changed
  observers$test_mode_startup_phase_changed <- register_observer(
    "test_mode_startup_phase_changed",
    shiny::observeEvent(app_state$events$test_mode_startup_phase_changed,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$HIGH,
      {
        current_phase <- app_state$test_mode$startup_phase

        if (exists("track_event")) {
          track_event("test_mode_startup_phase_changed", paste("phase:", current_phase))
        }

        log_debug_kv(
          message = paste("Startup phase changed to:", current_phase),
          phase = current_phase,
          .context = "[TEST_MODE_STARTUP]"
        )

        if (current_phase == "ui_ready") {
          emit$test_mode_startup_phase_changed("complete")
        } else if (current_phase == "complete") {
          app_state$test_mode$race_prevention_active <- FALSE
          log_info(
            message = "Test mode startup completed - race prevention disabled",
            .context = "[TEST_MODE_STARTUP]"
          )
        }
      }
    )
  )

  # Test mode debounced autodetect
  observers$test_mode_debounced_autodetect <- register_observer(
    "test_mode_debounced_autodetect",
    shiny::observeEvent(app_state$events$test_mode_debounced_autodetect,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$AUTO_DETECT,
      {
        if (!app_state$test_mode$race_prevention_active) {
          log_debug("Debounced autodetect skipped - race prevention disabled", .context = "[TEST_MODE_STARTUP]")
          return()
        }

        emit$auto_detection_started()
        emit$test_mode_startup_phase_changed("ui_ready")
      }
    )
  )

  # Error occurred
  observers$error_occurred <- register_observer(
    "error_occurred",
    shiny::observeEvent(app_state$events$error_occurred,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
      {
        error_context <- app_state$last_error_context
        error_info <- get_last_error(app_state)

        log_error("Consolidated error event triggered", .context = "ERROR_SYSTEM")

        if (!is.null(error_context)) {
          log_debug_kv(
            error_type = error_context$type %||% "unknown",
            error_context = error_context$context %||% "no context",
            error_details = if (!is.null(error_context$details)) {
              paste(names(error_context$details), collapse = ", ")
            } else {
              "none"
            },
            timestamp = as.character(error_context$timestamp %||% Sys.time()),
            session_id = if (!is.null(session)) sanitize_session_token(session$token) else "no session",
            .context = "ERROR_SYSTEM"
          )
        } else if (!is.null(error_info)) {
          log_debug_kv(
            error_type = error_info$type %||% "unknown",
            error_message = error_info$message %||% "no message",
            session_id = if (!is.null(session)) sanitize_session_token(session$token) else "no session",
            .context = "ERROR_SYSTEM"
          )
        }

        if (!is.null(error_context) && !is.null(emit)) {
          error_type <- error_context$type %||% "general"

          if (error_type == "processing") {
            increment_recovery_attempts(app_state)
            ctx <- error_context$context
            if (!is.null(ctx) && grepl("data|processing|convert|qic", ctx, ignore.case = TRUE)) {
              log_debug("Processing error detected - may need data validation", .context = "ERROR_SYSTEM")
            }
          } else if (error_type == "validation") {
            increment_recovery_attempts(app_state)
            log_debug("Validation error detected - clearing validation state", .context = "ERROR_SYSTEM")
          } else if (error_type == "network") {
            ctx <- error_context$context
            if (!is.null(ctx) && grepl("file|upload|download|io", ctx, ignore.case = TRUE)) {
              log_debug("Network/File I/O error detected", .context = "ERROR_SYSTEM")
            }
          } else if (error_type == "ui") {
            log_debug("UI error detected - may need UI synchronization", .context = "ERROR_SYSTEM")
          } else {
            log_debug(paste("General error of type:", error_type), "ERROR_SYSTEM")
          }
        }

        if (!is.null(app_state$errors)) {
          set_last_error(app_state, list(
            type = if (!is.null(error_context)) {
              error_context$type
            } else if (!is.null(error_info)) {
              error_info$type
            } else {
              "unknown"
            },
            context = if (!is.null(error_context)) error_context$context else "consolidated_handler",
            timestamp = Sys.time()
          ))
        }
      }
    )
  )

  # Recovery completed
  observers$recovery_completed <- register_observer(
    "recovery_completed",
    shiny::observeEvent(app_state$events$recovery_completed,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$LOW,
      {
        set_last_recovery_time(app_state)
        log_info("Error recovery completed", .context = "ERROR_SYSTEM")
        log_debug_kv(
          recovery_time = as.character(Sys.time()),
          session_id = if (!is.null(session)) sanitize_session_token(session$token) else "no session",
          .context = "ERROR_SYSTEM"
        )
      }
    )
  )

  observers
}
