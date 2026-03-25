#' State Accessor Functions
#'
#' Getter and setter functions for encapsulated app_state access.
#'
#' ## Architecture
#'
#' Instead of direct app_state access with inconsistent isolate() usage,
#' this module provides **accessor functions** that:
#'
#' **Benefits**:
#' - Consistent isolate() usage (prevents reactive dependency bugs)
#' - Encapsulation of state structure (easier to refactor schema)
#' - Type safety through validation
#' - Self-documenting code (function names describe purpose)
#' - Single source of truth for state access patterns
#'
#' ## Usage
#'
#' ```r
#' # Before (inconsistent, error-prone):
#' data <- isolate(app_state$data$current_data)
#'
#' # After (consistent, safe):
#' data <- get_current_data(app_state)
#' ```
#'
#' @name utils_state_accessors
NULL

# ============================================================================
# DATA ACCESSORS
# ============================================================================

#' Get Current Data
#'
#' Safely retrieves the current data from app_state.
#'
#' @param app_state Centralized app state
#'
#' @return Data frame or NULL
#'
#' @keywords internal
get_current_data <- function(app_state) {
  shiny::isolate(app_state$data$current_data)
}

#' Set Current Data
#'
#' Safely sets the current data in app_state.
#'
#' @param app_state Centralized app state
#' @param value Data frame to set
#'
#' @keywords internal
set_current_data <- function(app_state, value) {
  shiny::isolate({
    app_state$data$current_data <- value
  })
}

#' Set Original Data
#'
#' Safely sets the original (backup) data in app_state.
#'
#' @param app_state Centralized app state
#' @param value Data frame to set
#'
#' @keywords internal
set_original_data <- function(app_state, value) {
  shiny::isolate({
    app_state$data$original_data <- value
  })
}

# ============================================================================
# VISUALIZATION STATE ACCESSORS
# ============================================================================

#' Check if Plot is Ready
#'
#' Safely checks if the plot is ready to display.
#'
#' @param app_state Centralized app state
#'
#' @return Logical
#'
#' @keywords internal
is_plot_ready <- function(app_state) {
  shiny::isolate(app_state$visualization$plot_ready %||% FALSE)
}

#' Get Viewport Dimensions
#'
#' Safely retrieves viewport dimensions with fallback to defaults.
#'
#' M10: Centralized viewport state management
#'
#' @param app_state Centralized app state
#'
#' @return Named list with width, height, last_updated
#'
#' @details
#' Returns VIEWPORT_DEFAULTS if dimensions haven't been set yet.
#'
#' @keywords internal
get_viewport_dims <- function(app_state) {
  shiny::isolate({
    dims <- app_state$visualization$viewport_dims

    # Fallback to defaults if not yet set
    if (is.null(dims$width) || is.null(dims$height)) {
      return(list(
        width = VIEWPORT_DEFAULTS$width,
        height = VIEWPORT_DEFAULTS$height,
        last_updated = NULL
      ))
    }

    return(dims)
  })
}

#' Set Viewport Dimensions
#'
#' Safely updates viewport dimensions and triggers visualization update.
#'
#' M10: Centralized viewport state management
#'
#' @param app_state Centralized app state
#' @param width Viewport width in pixels
#' @param height Viewport height in pixels
#' @param emit Emit API (optional) for triggering visualization_update_needed
#'
#' @keywords internal
set_viewport_dims <- function(app_state, width, height, emit = NULL) {
  shiny::isolate({
    app_state$visualization$viewport_dims <- list(
      width = width,
      height = height,
      last_updated = Sys.time()
    )
  })

  # Emit visualization update if emit API available
  if (!is.null(emit) && is.function(emit$visualization_update_needed)) {
    emit$visualization_update_needed()
  }
}
