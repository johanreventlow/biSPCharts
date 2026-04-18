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
  # Change detection: emit kun ved reel ændring i dimensioner
  current <- shiny::isolate(app_state$visualization$viewport_dims)
  dims_changed <- is.null(current) ||
    !identical(current$width, width) ||
    !identical(current$height, height)

  if (!dims_changed) return(invisible(NULL))

  shiny::isolate({
    app_state$visualization$viewport_dims <- list(
      width = width,
      height = height,
      last_updated = Sys.time()
    )
  })

  if (!is.null(emit) && is.function(emit$visualization_update_needed)) {
    emit$visualization_update_needed()
  }
}

# ============================================================================
# DATA ACCESSORS — FASE 3 ADDITIONS
# ============================================================================

#' Get Original Data
#'
#' Safely retrieves the original (backup) data from app_state.
#'
#' @param app_state Centralized app state
#'
#' @return Data frame or NULL
#'
#' @keywords internal
get_original_data <- function(app_state) {
  shiny::isolate(app_state$data$original_data)
}

#' Check if Table is Updating
#'
#' Safely checks if a table operation is in progress.
#'
#' @param app_state Centralized app state
#'
#' @return Logical
#'
#' @keywords internal
is_table_updating <- function(app_state) {
  shiny::isolate(app_state$data$updating_table %||% FALSE)
}

#' Set Table Updating Flag
#'
#' Sets the table-updating flag in app_state.
#'
#' @param app_state Centralized app state
#' @param value Logical value
#'
#' @keywords internal
set_table_updating <- function(app_state, value) {
  shiny::isolate({
    app_state$data$updating_table <- value
  })
}

# ============================================================================
# COLUMN ACCESSORS — FASE 3 ADDITIONS
# ============================================================================

#' Get Auto-Detect Status
#'
#' Returns the current auto-detection status as a named list.
#'
#' @param app_state Centralized app state
#'
#' @return Named list with in_progress, completed, results, frozen
#'
#' @keywords internal
get_autodetect_status <- function(app_state) {
  shiny::isolate(list(
    in_progress = app_state$columns$auto_detect$in_progress %||% FALSE,
    completed = app_state$columns$auto_detect$completed %||% FALSE,
    results = app_state$columns$auto_detect$results,
    frozen = app_state$columns$auto_detect$frozen_until_next_trigger %||% FALSE
  ))
}

#' Set Auto-Detect In Progress
#'
#' Sets the auto-detection in-progress flag.
#'
#' @param app_state Centralized app state
#' @param value Logical value
#'
#' @keywords internal
set_autodetect_in_progress <- function(app_state, value) {
  shiny::isolate({
    app_state$columns$auto_detect$in_progress <- value
  })
}

#' Get All Column Mappings
#'
#' Returns all column mappings as a named list.
#'
#' @param app_state Centralized app state
#'
#' @return Named list of column mappings
#'
#' @keywords internal
get_column_mappings <- function(app_state) {
  shiny::isolate(shiny::reactiveValuesToList(app_state$columns$mappings))
}

#' Get Single Column Mapping
#'
#' Returns the value for a single column mapping key.
#'
#' @param app_state Centralized app state
#' @param key Character string — mapping key (e.g. "x_column")
#'
#' @return Character or NULL
#'
#' @keywords internal
get_column_mapping <- function(app_state, key) {
  shiny::isolate(app_state$columns$mappings[[key]])
}

#' Update Single Column Mapping
#'
#' Sets a single column mapping key to a new value.
#'
#' @param app_state Centralized app state
#' @param key Character string — mapping key
#' @param value Character string or NULL
#'
#' @keywords internal
update_column_mapping <- function(app_state, key, value) {
  shiny::isolate({
    app_state$columns$mappings[[key]] <- value
  })
}

# ============================================================================
# VISUALIZATION ACCESSORS — FASE 3 ADDITIONS
# ============================================================================

#' Set Plot Ready
#'
#' Sets the plot-ready flag in app_state.
#'
#' @param app_state Centralized app state
#' @param value Logical value
#'
#' @keywords internal
set_plot_ready <- function(app_state, value) {
  shiny::isolate({
    app_state$visualization$plot_ready <- value
  })
}

#' Get Plot Warnings
#'
#' Safely retrieves current plot warnings.
#'
#' @param app_state Centralized app state
#'
#' @return Character vector (empty if none)
#'
#' @keywords internal
get_plot_warnings <- function(app_state) {
  shiny::isolate(app_state$visualization$plot_warnings %||% character(0))
}

#' Set Plot Warnings
#'
#' Sets plot warnings in app_state.
#'
#' @param app_state Centralized app state
#' @param value Character vector
#'
#' @keywords internal
set_plot_warnings <- function(app_state, value) {
  shiny::isolate({
    app_state$visualization$plot_warnings <- value
  })
}

#' Get Plot Object
#'
#' Safely retrieves the current plot object.
#'
#' @param app_state Centralized app state
#'
#' @return ggplot object or NULL
#'
#' @keywords internal
get_plot_object <- function(app_state) {
  shiny::isolate(app_state$visualization$plot_object)
}

#' Set Plot Object
#'
#' Sets the plot object in app_state.
#'
#' @param app_state Centralized app state
#' @param value ggplot object or NULL
#'
#' @keywords internal
set_plot_object <- function(app_state, value) {
  shiny::isolate({
    app_state$visualization$plot_object <- value
  })
}

#' Check if Plot is Generating
#'
#' Safely checks if a plot generation is in progress.
#'
#' @param app_state Centralized app state
#'
#' @return Logical
#'
#' @keywords internal
is_plot_generating <- function(app_state) {
  shiny::isolate(app_state$visualization$is_computing %||% FALSE)
}

#' Set Plot Generating Flag
#'
#' Sets the plot-generating (is_computing) flag in app_state.
#'
#' @param app_state Centralized app state
#' @param value Logical value
#'
#' @keywords internal
set_plot_generating <- function(app_state, value) {
  shiny::isolate({
    app_state$visualization$is_computing <- value
  })
}

# ============================================================================
# SESSION ACCESSORS — FASE 3 ADDITIONS
# ============================================================================

#' Check if File is Uploaded
#'
#' Safely checks if a file has been uploaded in the current session.
#'
#' @param app_state Centralized app state
#'
#' @return Logical
#'
#' @keywords internal
is_file_uploaded <- function(app_state) {
  shiny::isolate(app_state$session$file_uploaded %||% FALSE)
}

#' Set File Uploaded Flag
#'
#' Sets the file-uploaded flag in app_state.
#'
#' @param app_state Centralized app state
#' @param value Logical value
#'
#' @keywords internal
set_file_uploaded <- function(app_state, value) {
  shiny::isolate({
    app_state$session$file_uploaded <- value
  })
}

#' Check if User Session is Started
#'
#' Safely checks if the user has started a session (uploaded data etc.).
#'
#' @param app_state Centralized app state
#'
#' @return Logical
#'
#' @keywords internal
is_user_session_started <- function(app_state) {
  shiny::isolate(app_state$session$user_started_session %||% FALSE)
}

#' Set User Session Started Flag
#'
#' Sets the user-started-session flag in app_state.
#'
#' @param app_state Centralized app state
#' @param value Logical value
#'
#' @keywords internal
set_user_session_started <- function(app_state, value) {
  shiny::isolate({
    app_state$session$user_started_session <- value
  })
}

# ============================================================================
# ERROR STATE ACCESSORS — FASE 3 ADDITIONS (ny sub-sektion)
# ============================================================================

# Ensure the errors sub-state is initialised once per create_app_state() call.
# It is bootstrapped lazily here so we do not need to touch state_management.R.

.ensure_errors_state <- function(app_state) {
  if (is.null(shiny::isolate(app_state$errors))) {
    app_state$errors <- shiny::reactiveValues(
      error_list = list(),
      error_count = 0L
    )
  }
}

#' Get Last Error
#'
#' Returns the most recently recorded error or NULL if none.
#'
#' @param app_state Centralized app state
#'
#' @return Named list or NULL
#'
#' @keywords internal
get_last_error <- function(app_state) {
  .ensure_errors_state(app_state)
  shiny::isolate({
    lst <- app_state$errors$error_list
    if (length(lst) == 0L) NULL else lst[[length(lst)]]
  })
}

#' Set Last Error
#'
#' Records a new error and increments the error counter.
#'
#' @param app_state Centralized app state
#' @param value Named list describing the error
#'
#' @keywords internal
set_last_error <- function(app_state, value) {
  .ensure_errors_state(app_state)
  shiny::isolate({
    app_state$errors$error_list <- c(app_state$errors$error_list, list(value))
    app_state$errors$error_count <- app_state$errors$error_count + 1L
  })
}

#' Get Error Count
#'
#' Returns the total number of errors recorded in the current session.
#'
#' @param app_state Centralized app state
#'
#' @return Integer
#'
#' @keywords internal
get_error_count <- function(app_state) {
  .ensure_errors_state(app_state)
  shiny::isolate(app_state$errors$error_count %||% 0L)
}

# ============================================================================
# TEST MODE ACCESSORS — FASE 3 ADDITIONS
# ============================================================================

#' Check if Test Mode is Enabled
#'
#' Safely checks whether the app is running in test mode.
#'
#' @param app_state Centralized app state
#'
#' @return Logical
#'
#' @keywords internal
is_test_mode_enabled <- function(app_state) {
  shiny::isolate(app_state$test_mode$enabled %||% FALSE)
}

#' Set Test Mode Enabled
#'
#' Enables or disables test mode in app_state.
#'
#' @param app_state Centralized app state
#' @param value Logical value
#'
#' @keywords internal
set_test_mode_enabled <- function(app_state, value) {
  shiny::isolate({
    app_state$test_mode$enabled <- value
  })
}

#' Get Test Mode Startup Phase
#'
#' Returns the current startup phase string for test mode.
#'
#' @param app_state Centralized app state
#'
#' @return Character — one of "initializing", "data_ready", "ui_ready", "complete"
#'
#' @keywords internal
get_test_mode_startup_phase <- function(app_state) {
  shiny::isolate(app_state$test_mode$startup_phase %||% "initializing")
}

#' Set Test Mode Startup Phase
#'
#' Updates the startup phase in test mode state.
#'
#' @param app_state Centralized app state
#' @param value Character string — startup phase name
#'
#' @keywords internal
set_test_mode_startup_phase <- function(app_state, value) {
  shiny::isolate({
    app_state$test_mode$startup_phase <- value
  })
}

# ============================================================================
# UI ACCESSORS — FASE 3 ADDITIONS
# ============================================================================

#' Check if Anhøj Rules are Hidden
#'
#' Safely checks whether the Anhøj rules panel is hidden.
#'
#' @param app_state Centralized app state
#'
#' @return Logical
#'
#' @keywords internal
is_anhoej_rules_hidden <- function(app_state) {
  shiny::isolate(app_state$ui$hide_anhoej_rules %||% FALSE)
}

#' Set Anhøj Rules Hidden
#'
#' Shows or hides the Anhøj rules panel.
#'
#' @param app_state Centralized app state
#' @param value Logical value
#'
#' @keywords internal
set_anhoej_rules_hidden <- function(app_state, value) {
  shiny::isolate({
    app_state$ui$hide_anhoej_rules <- value
  })
}

#' Check if Y-Axis Autoset is Done
#'
#' Safely checks whether the automatic y-axis unit detection has been applied.
#'
#' @param app_state Centralized app state
#'
#' @return Logical
#'
#' @keywords internal
is_y_axis_autoset_done <- function(app_state) {
  shiny::isolate(app_state$ui$y_axis_unit_autoset_done %||% FALSE)
}

#' Set Y-Axis Autoset Done
#'
#' Marks the automatic y-axis unit detection as done (or resets the flag).
#'
#' @param app_state Centralized app state
#' @param value Logical value
#'
#' @keywords internal
set_y_axis_autoset_done <- function(app_state, value) {
  shiny::isolate({
    app_state$ui$y_axis_unit_autoset_done <- value
  })
}
