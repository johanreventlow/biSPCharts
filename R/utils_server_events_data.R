# ==============================================================================
# utils_server_events_data.R
# ==============================================================================
# DATA LIFECYCLE EVENT HANDLERS
#
# Extracted from: utils_server_event_listeners.R (Phase 2d refactoring)
# ==============================================================================

#' Register Data Lifecycle Events
#'
#' Registers observers for data loading, changes, and updates.
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
#' Handles all events related to data lifecycle:
#' - data_updated: Consolidated handler for data_loaded + data_changed
#' - Cache clearing on data updates
#' - Context-aware processing (load vs. edit vs. general)
#' - Y-axis reset on data update
register_data_lifecycle_events <- function(app_state, emit, input, output, session, ui_service, register_observer) {
  observers <- list()

  # Consolidated data update handler (REFACTORED: Using strategy pattern)
  observers$data_updated <- register_observer(
    "data_updated",
    shiny::observeEvent(app_state$events$data_updated,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
      {
        update_context <- app_state$last_data_update_context

        # SPRINT 4: Smart QIC cache invalidation (context-aware)
        invalidate_qic_cache_smart(app_state, update_context)

        # Legacy performance cache clearing
        if (exists("clear_performance_cache") && is.function(clear_performance_cache)) {
          safe_operation(
            "Clear performance cache on data update",
            code = {
              clear_performance_cache()
              log_debug("Performance cache cleared due to data update", .context = "CACHE_INVALIDATION")
            },
            fallback = function(e) {
              log_warn(paste("Failed to clear cache:", e$message), .context = "CACHE_INVALIDATION")
            }
          )
        }

        # Unfreeze autodetect system when data is updated
        app_state$columns$auto_detect$frozen_until_next_trigger <- FALSE

        # REFACTORED: Use strategy pattern for context-aware processing
        # Replaces complex nested if/else (cyclomatic complexity 12 → 3)
        handle_data_update_by_context(
          update_context = update_context,
          app_state = app_state,
          emit = emit,
          input = input,
          output = output,
          session = session,
          ui_service = ui_service
        )
      }
    )
  )

  # Reset auto-default flag for Y-axis when data updates
  observers$data_updated_y_axis_reset <- register_observer(
    "data_updated_y_axis_reset",
    shiny::observeEvent(app_state$events$data_updated,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$LOWEST,
      {
        if (!is.null(app_state$ui)) {
          app_state$ui$y_axis_unit_autoset_done <- FALSE
        }
      }
    )
  )

  observers
}
