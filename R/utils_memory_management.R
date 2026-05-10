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
          set_current_data(app_state, NULL)
          set_original_data(app_state, NULL)
          set_table_updating(app_state, FALSE)
          set_table_op_in_progress(app_state, FALSE)
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

    # Cycle E NEW1 (Codex 2026-05-10): cleanup tempdir-PNG-akkumulation.
    # Defense-in-depth — explicit preview_path-fix i mod_export_server.R
    # holder filerne under én sti, men hvis legacy tempfile()-callers (eller
    # tests) lægger PNGs udenfor, fanger denne pattern dem.
    safe_operation(
      "Cleanup PDF preview temp PNGs",
      code = {
        png_files <- list.files(
          tempdir(),
          pattern = "^bfh_preview_",
          full.names = TRUE
        )
        if (length(png_files) > 0) {
          unlink(png_files, recursive = FALSE, force = TRUE)
          log_debug(
            sprintf("Cleaned up %d temp PNG file(s)", length(png_files)),
            .context = "MEMORY_MGMT"
          )
        }
      },
      fallback = function(e) {
        log_warn(paste("Temp PNG cleanup failed:", e$message), "MEMORY_MGMT")
      },
      error_type = "processing"
    )

    # Force garbage collection
    gc(verbose = FALSE)

    log_info("Session cleanup completed", .context = "MEMORY_MGMT")
  })
}
