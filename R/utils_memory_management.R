# utils_memory_management.R
# Memory management utilities for session cleanup

#' Session cleanup utilities for memory management
#'
#' Registers cleanup handler on session end to free memory and resources.
#'
#' @param session Shiny session object
#' @param app_state App state object (optional)
#' @param observers List of observer objects (optional)
#'
#' @family memory_management
#' @keywords internal
setup_session_cleanup <- function(session, app_state = NULL, observers = NULL) {
  session$onSessionEnded(function() {
    log_info("Starting session cleanup", .context = "MEMORY_MGMT")

    # Clear performance caches
    clear_performance_cache()

    # Clear centralized state if provided
    if (!is.null(app_state) && !is.null(app_state$data)) {
      safe_operation(
        "Reset app state during cleanup",
        code = {
          app_state$data$current_data <- NULL
          app_state$data$original_data <- NULL
          app_state$data$updating_table <- FALSE
          app_state$data$table_operation_in_progress <- FALSE
        },
        fallback = function(e) {
          log_debug("Could not reset app state during cleanup", .context = "MEMORY_MGMT")
        },
        error_type = "processing"
      )
    }

    # Destroy observers if provided
    if (!is.null(observers)) {
      for (obs in if (is.list(observers)) observers else list(observers)) {
        safe_operation(
          "Destroy observer",
          code = {
            if (inherits(obs, "Observer")) obs$destroy()
          },
          fallback = function(e) {
            log_warn(paste("Failed to destroy observer:", e$message), "MEMORY_MGMT")
          },
          error_type = "processing"
        )
      }
    }

    # Force garbage collection
    gc(verbose = FALSE)

    log_info("Session cleanup completed", .context = "MEMORY_MGMT")
  })
}
