# utils_server_initialization.R
# Server initialization helper functions
# Extracted from app_server_main.R for better maintainability (Sprint 1)

#' Initialize App Infrastructure
#'
#' Sets up core app infrastructure including state management, event system,
#' UI service, and logging.
#'
#' @param session Shiny session object
#' @param hashed_token Hashed session token for logging
#' @param session_debugger Session debugger object
#'
#' @return List with app_state, emit, ui_service components
#'
#' @details
#' This function initializes the core infrastructure needed for the SPC app:
#' - Creates centralized app_state for reactive state management
#' - Sets up event-driven architecture via emit API
#' - Initializes UI update service for programmatic updates
#' - Configures shinylogs tracking (if enabled)
#' - Registers event listeners with proper cleanup
#'
#' @examples
#' \dontrun{
#' # In main_app_server()
#' session_token <- session$token %||% paste0("session_", Sys.time())
#' hashed_token <- hash_session_token(session_token)
#' session_debugger <- debug_session_lifecycle(hashed_token, session)
#'
#' infrastructure <- initialize_app_infrastructure(
#'   session = session,
#'   hashed_token = hashed_token,
#'   session_debugger = session_debugger
#' )
#'
#' # Extract components for use in server logic
#' app_state <- infrastructure$app_state
#' emit <- infrastructure$emit
#' ui_service <- infrastructure$ui_service
#'
#' # Use emit API to trigger events
#' emit$data_updated(context = "file_upload")
#' emit$auto_detection_started()
#' }
#'
#' @keywords internal
initialize_app_infrastructure <- function(session, hashed_token, session_debugger) {
  log_debug("Initializing app infrastructure", .context = "APP_INIT")

  # Centralized state management using unified app_state architecture
  app_state <- create_app_state()
  session_debugger$event("centralized_state_initialized")

  # EVENT SYSTEM: Initialize reactive event bus
  emit <- create_emit_api(app_state)
  log_debug("Event system initialized", .context = "APP_INIT")

  # UI SERVICE: Initialize centralized UI update service
  ui_service <- create_ui_update_service(session, app_state)
  log_debug("UI update service initialized", .context = "APP_INIT")

  # ANALYTICS: Setup consent gate (erstatter direkte shinylogs init)
  # shinylogs initialiseres KUN naar bruger har givet consent via cookie-banner
  if (should_enable_shinylogs()) {
    setup_analytics_consent(
      input = session$input,
      session = session,
      hashed_token = hashed_token,
      log_directory = "logs/"
    )
    log_debug("Analytics consent gate registered", .context = "APP_INIT")
  }

  # EVENT SYSTEM: Set up reactive event listeners AFTER shinylogs setup
  # SESSION FLAG: Prevent duplicate event listener registration
  safe_operation(
    "Initialize event listeners setup flag",
    code = {
      if (is.null(app_state$infrastructure$event_listeners_setup)) {
        app_state$infrastructure$event_listeners_setup <- FALSE
      }
    },
    fallback = function(e) {
      log_error(
        paste("ERROR initializing event_listeners_setup flag:", e$message),
        .context = "APP_INIT"
      )
    },
    error_type = "processing"
  )

  safe_operation(
    "Setup event listeners",
    code = {
      setup_event_listeners(app_state, emit, input = session$input, output = session$output, session, ui_service)
      app_state$infrastructure$event_listeners_setup <- TRUE
    },
    fallback = function(e) {
      log_error(paste("ERROR in setup_event_listeners:", e$message), .context = "APP_INIT")
    },
    error_type = "processing"
  )

  # Take initial state snapshot
  shiny::observeEvent(
    shiny::reactive(TRUE),
    {
      shiny::isolate({
        initial_snapshot <- debug_state_snapshot("app_initialization", app_state, session_id = hashed_token)
      })
    },
    once = TRUE,
    priority = OBSERVER_PRIORITIES$LOW,
    ignoreInit = FALSE
  )

  log_debug("App infrastructure initialized", .context = "APP_INIT")

  return(list(
    app_state = app_state,
    emit = emit,
    ui_service = ui_service
  ))
}

#' Setup Background Tasks
#'
#' Configures periodic background maintenance tasks including cleanup and
#' performance monitoring.
#'
#' @param session Shiny session object
#' @param app_state Centralized app state
#' @param emit Event emission API
#'
#' @details
#' Sets up two periodic background tasks:
#' - System cleanup (every 5 minutes): Removes stale cache entries, cleans up observers
#' - Performance monitoring (every 15 minutes): Reports system health metrics
#'
#' Both tasks check session_active flag and stop automatically when session ends.
#'
#' @examples
#' \dontrun{
#' # After initializing infrastructure
#' setup_background_tasks(
#'   session = session,
#'   app_state = app_state,
#'   emit = emit
#' )
#'
#' # Background tasks will run automatically:
#' # - Cleanup every 5 minutes
#' # - Performance reports every 15 minutes
#' # - Both stop when session$onSessionEnded triggers
#' }
#'
#' @keywords internal
setup_background_tasks <- function(session, app_state, emit) {
  log_debug("Setting up background tasks", .context = "BACKGROUND_TASKS")

  # AUTOMATIC BACKGROUND CLEANUP - Schedule periodic system maintenance
  if (requireNamespace("later", quietly = TRUE)) {
    cleanup_interval_minutes <- 5

    later::later(
      function() {
        shiny::withReactiveDomain(session, {
          # Recursive cleanup scheduler
          schedule_periodic_cleanup <- function() {
            # Check if session is still active
            session_check <- !app_state$infrastructure$session_active ||
              !app_state$infrastructure$background_tasks_active
            if (session_check) {
              log_debug("Stopping periodic cleanup - session ended", .context = "BACKGROUND_CLEANUP")
              return()
            }

            log_debug("Running scheduled comprehensive system cleanup", .context = "BACKGROUND_CLEANUP")
            safe_operation(
              "Scheduled system cleanup",
              code = {
                comprehensive_system_cleanup(app_state)
                log_debug("Scheduled cleanup completed successfully", .context = "BACKGROUND_CLEANUP")
              },
              fallback = NULL,
              session = session,
              error_type = "processing",
              emit = emit,
              app_state = app_state
            )

            # Schedule next cleanup only if session is still active
            should_continue <- app_state$infrastructure$session_active &&
              app_state$infrastructure$background_tasks_active
            if (should_continue) {
              later::later(schedule_periodic_cleanup, delay = cleanup_interval_minutes * 60)
            }
          }

          # Start the periodic cleanup cycle
          schedule_periodic_cleanup()
        })
      },
      delay = cleanup_interval_minutes * 60
    )

    log_debug(
      paste("Background cleanup scheduled every", cleanup_interval_minutes, "minutes"),
      .context = "BACKGROUND_TASKS"
    )
  } else {
    log_warn("later package not available - background cleanup disabled", .context = "BACKGROUND_TASKS")
  }

  # PERFORMANCE MONITORING INTEGRATION - Schedule periodic reporting
  if (requireNamespace("later", quietly = TRUE)) {
    report_interval_minutes <- 15

    later::later(
      function() {
        shiny::withReactiveDomain(session, {
          # Recursive performance reporting
          schedule_periodic_reporting <- function() {
            # Check if session is still active
            session_check <- !app_state$infrastructure$session_active ||
              !app_state$infrastructure$background_tasks_active
            if (session_check) {
              return()
            }

            safe_operation(
              "Performance report generation",
              code = {
                report <- get_performance_report(app_state)
                log_debug(report$formatted_text, .context = "PERFORMANCE_MONITOR")

                # Check if system needs attention
                if (report$health_status == "WARNING") {
                  log_warn(
                    paste(
                      "System health WARNING - Queue:", report$queue_utilization_pct,
                      "% | Tokens:", report$token_utilization_pct, "%"
                    ),
                    .context = "PERFORMANCE_MONITOR"
                  )
                }
              },
              fallback = NULL,
              session = session,
              error_type = "processing",
              emit = emit,
              app_state = app_state
            )

            # Schedule next report only if session is still active
            should_continue <- app_state$infrastructure$session_active &&
              app_state$infrastructure$background_tasks_active
            if (should_continue) {
              later::later(schedule_periodic_reporting, delay = report_interval_minutes * 60)
            }
          }

          # Start the periodic reporting cycle
          schedule_periodic_reporting()
        })
      },
      delay = report_interval_minutes * 60
    )

    log_debug(
      paste("Performance monitoring scheduled every", report_interval_minutes, "minutes"),
      .context = "BACKGROUND_TASKS"
    )
  }

  log_debug("Background tasks configured", .context = "BACKGROUND_TASKS")
}
