# ==============================================================================
# utils_server_events_ui.R
# ==============================================================================
# UI SYNCHRONIZATION EVENT HANDLERS
#
# Extracted from: utils_server_event_listeners.R (Phase 2d refactoring)
# ==============================================================================

#' Register UI Sync Events
#'
#' Registers observers for UI synchronization.
#'
#' @param app_state Centralized app state
#' @param emit Event emission API
#' @param input Shiny input
#' @param output Shiny output
#' @param session Shiny session
#' @param ui_service UI service for UI updates
#' @param register_observer Function to register observer for cleanup
#'
#' @return Named list of registered observers
#'
#' @details
#' Handles UI synchronization events:
#' - ui_sync_requested: Syncs UI controls with detected columns (throttled 250ms)
#' - ui_sync_completed: Marks sync completion, triggers navigation
register_ui_sync_events <- function(app_state, emit, input, output, session, ui_service, register_observer) {
  observers <- list()

  # PERFORMANCE: Throttle UI sync to reduce update overhead (250ms)
  # This prevents excessive UI updates during rapid event chains while
  # maintaining imperceptible user experience (<250ms delay)
  throttled_ui_sync <- shiny::throttle(
    shiny::reactive({
      app_state$events$ui_sync_requested
    }),
    millis = 250
  )

  observers$ui_sync_requested <- register_observer(
    "ui_sync_requested",
    shiny::observeEvent(throttled_ui_sync(),
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$UI_SYNC,
      {
        safe_operation(
          "UI synchronization",
          code = {
            # Perform UI synchronization
            sync_ui_with_columns_unified(app_state, input, output, session, ui_service)

            # CONSOLIDATED: Handle general UI updates (from ui_update_needed)
            if (!is.null(ui_service) && !is.null(app_state$data$current_data)) {
              ui_service$update_column_choices()
            }
          },
          fallback = NULL,
          session = session,
          error_type = "processing",
          emit = emit,
          app_state = app_state
        )

        # Mark sync as completed
        emit$ui_sync_completed()
      }
    )
  )

  observers$ui_sync_completed <- register_observer(
    "ui_sync_completed",
    shiny::observeEvent(app_state$events$ui_sync_completed,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$UI_SYNC,
      {
        # Update timestamp
        app_state$columns$ui_sync$last_sync_time <- Sys.time()

        # Auto-set Y-axis unit after run chart + N availability (only once per data load)
        safe_operation(
          "Auto-set y-axis unit after UI sync",
          code = {
            already_set <- isTRUE(shiny::isolate(app_state$ui$y_axis_unit_autoset_done))
            if (!already_set) {
              ct <- get_qic_chart_type(input$chart_type %||% "run")
              columns_state <- shiny::isolate(app_state$columns)
              n_val <- tryCatch(shiny::isolate(columns_state$n_column), error = function(...) NULL)
              if (is.null(n_val)) {
                n_val <- tryCatch(shiny::isolate(columns_state$mappings$n_column), error = function(...) NULL)
              }
              n_present <- !is.null(n_val) && nzchar(n_val)
              if (identical(ct, "run")) {
                default_unit <- decide_default_y_axis_ui_type(ct, n_present)
                current_unit <- input$y_axis_unit %||% "count"
                if (!identical(current_unit, default_unit)) {
                  safe_programmatic_ui_update(session, app_state, function() {
                    shiny::updateSelectizeInput(session, "y_axis_unit", selected = default_unit)
                  })
                }
                app_state$ui$y_axis_unit_autoset_done <- TRUE
                log_debug_kv(
                  message = "Auto-set y-axis unit",
                  chart_type = ct,
                  n_present = n_present,
                  from = current_unit,
                  to = default_unit,
                  .context = "[Y_AXIS_UI]"
                )
              }
            }
          },
          fallback = NULL,
          session = session,
          error_type = "processing"
        )

        # Trigger navigation change to update plots
        emit$navigation_changed()
      }
    )
  )

  observers
}
