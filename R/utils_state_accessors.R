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

  if (!dims_changed) {
    return(invisible(NULL))
  }

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
# KOLONNE-SPECIFIKKE ACCESSORS — FASE 4 (fix-state-paths-and-restore-guards)
# ============================================================================

#' Hent X-kolonne mapping
#'
#' Returnerer den aktuelle x_column-mapping fra app_state.
#'
#' @param app_state Centraliseret app state
#'
#' @return Character eller NULL
#'
#' @keywords internal
get_x_column <- function(app_state) {
  shiny::isolate(app_state$columns$mappings$x_column)
}

#' Hent Y-kolonne mapping
#'
#' Returnerer den aktuelle y_column-mapping fra app_state.
#'
#' @param app_state Centraliseret app state
#'
#' @return Character eller NULL
#'
#' @keywords internal
get_y_column <- function(app_state) {
  shiny::isolate(app_state$columns$mappings$y_column)
}

#' Hent N-kolonne (nævner) mapping
#'
#' Returnerer den aktuelle n_column-mapping fra app_state.
#'
#' @param app_state Centraliseret app state
#'
#' @return Character eller NULL
#'
#' @keywords internal
get_n_column <- function(app_state) {
  shiny::isolate(app_state$columns$mappings$n_column)
}

#' Hent skift-kolonne mapping
#'
#' Returnerer den aktuelle skift_column-mapping fra app_state.
#'
#' @param app_state Centraliseret app state
#'
#' @return Character eller NULL
#'
#' @keywords internal
get_skift_column <- function(app_state) {
  shiny::isolate(app_state$columns$mappings$skift_column)
}

#' Hent frys-kolonne mapping
#'
#' Returnerer den aktuelle frys_column-mapping fra app_state.
#'
#' @param app_state Centraliseret app state
#'
#' @return Character eller NULL
#'
#' @keywords internal
get_frys_column <- function(app_state) {
  shiny::isolate(app_state$columns$mappings$frys_column)
}

#' Hent kommentar-kolonne mapping
#'
#' Returnerer den aktuelle kommentar_column-mapping fra app_state.
#'
#' @param app_state Centraliseret app state
#'
#' @return Character eller NULL
#'
#' @keywords internal
get_kommentar_column <- function(app_state) {
  shiny::isolate(app_state$columns$mappings$kommentar_column)
}

# ============================================================================
# SESSION-RESTORE ACCESSOR — FASE 4 (fix-state-paths-and-restore-guards)
# ============================================================================

#' Check om session er under genopretning
#'
#' Returnerer TRUE hvis app_state$session$restoring_session er sat,
#' dvs. at appen er i gang med at gendanne en gemt session fra localStorage.
#' Bruges som guard i observers der ikke må reagere på UI-ændringer
#' foretaget af restore-logikken.
#'
#' @param app_state Centraliseret app state
#'
#' @return Logical
#'
#' @keywords internal
is_restoring_session <- function(app_state) {
  shiny::isolate(app_state$session$restoring_session %||% FALSE)
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
# ERROR STATE ACCESSORS
# ============================================================================
#
# Canonical schema lives in `create_app_state()` (state_management.R):
#   last_error, error_count, error_history (cap 10), recovery_attempts,
#   last_recovery_time. All access goes through these accessors so callers
#   never reach into `app_state$errors$*` directly. See issue #444.

# Maximum entries kept in `error_history` (FIFO eviction).
ERROR_HISTORY_CAP <- 10L

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
  shiny::isolate(app_state$errors$last_error)
}

#' Set Last Error
#'
#' Records a new error: updates `last_error`, appends to `error_history`
#' (capped at `ERROR_HISTORY_CAP` via FIFO eviction) and increments
#' `error_count`.
#'
#' @param app_state Centralized app state
#' @param value Named list describing the error
#'
#' @keywords internal
set_last_error <- function(app_state, value) {
  shiny::isolate({
    app_state$errors$last_error <- value
    history <- c(app_state$errors$error_history, list(value))
    if (length(history) > ERROR_HISTORY_CAP) {
      history <- history[(length(history) - ERROR_HISTORY_CAP + 1L):length(history)]
    }
    app_state$errors$error_history <- history
    app_state$errors$error_count <- (app_state$errors$error_count %||% 0L) + 1L
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
  shiny::isolate(app_state$errors$error_count %||% 0L)
}

#' Get Error History
#'
#' Returns the recent error history (max `ERROR_HISTORY_CAP`, FIFO).
#'
#' @param app_state Centralized app state
#'
#' @return List of error records (oldest first)
#'
#' @keywords internal
get_error_history <- function(app_state) {
  shiny::isolate(app_state$errors$error_history %||% list())
}

#' Get Recovery Attempts
#'
#' @param app_state Centralized app state
#'
#' @return Integer
#'
#' @keywords internal
get_recovery_attempts <- function(app_state) {
  shiny::isolate(app_state$errors$recovery_attempts %||% 0L)
}

#' Increment Recovery Attempts
#'
#' Adds 1 to the recovery-attempt counter.
#'
#' @param app_state Centralized app state
#'
#' @keywords internal
increment_recovery_attempts <- function(app_state) {
  shiny::isolate({
    app_state$errors$recovery_attempts <- (app_state$errors$recovery_attempts %||% 0L) + 1L
  })
}

#' Get Last Recovery Time
#'
#' @param app_state Centralized app state
#'
#' @return POSIXct or NULL
#'
#' @keywords internal
get_last_recovery_time <- function(app_state) {
  shiny::isolate(app_state$errors$last_recovery_time)
}

#' Set Last Recovery Time
#'
#' @param app_state Centralized app state
#' @param value POSIXct timestamp (default `Sys.time()`)
#'
#' @keywords internal
set_last_recovery_time <- function(app_state, value = Sys.time()) {
  shiny::isolate({
    app_state$errors$last_recovery_time <- value
  })
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

# ============================================================================
# STATE-DISCIPLIN — FASE A (Issue #424)
# ============================================================================
# Accessors for top-recurrence-keys der tidligere blev muteret direkte.
# Konsoliderer mutations gennem named API for testbarhed + lint-disciplin.

#' Set Table Operation In Progress
#'
#' Toggle for igangvaerende tabel-operation (cleanup-debounce + race-guards).
#' Bruges af utils_server_session_helpers, utils_server_column_management,
#' utils_memory_management.
#'
#' @param app_state Centralized app state
#' @param value Logical TRUE/FALSE
#'
#' @keywords internal
set_table_op_in_progress <- function(app_state, value) {
  shiny::isolate({
    app_state$data$table_operation_in_progress <- value
  })
}

#' Set Session Restoring Flag
#'
#' Toggle for igangvaerende session-restore. Forhindrer auto-detection +
#' auto-save trigger under restore-flow (Issue #193, #393).
#'
#' @param app_state Centralized app state
#' @param value Logical TRUE/FALSE
#'
#' @keywords internal
set_session_restoring <- function(app_state, value) {
  shiny::isolate({
    app_state$session$restoring_session <- value
  })
}

#' Set UI Updating Programmatically Flag
#'
#' Toggle for igangvaerende programmatisk UI-update. Brugt af
#' safe_programmatic_ui_update() til race-protection mod brugerinteraktion.
#'
#' @param app_state Centralized app state
#' @param value Logical TRUE/FALSE
#'
#' @keywords internal
set_ui_updating <- function(app_state, value) {
  shiny::isolate({
    app_state$ui$updating_programmatically <- value
  })
}

#' Set Visualization Cache Updating Flag
#'
#' Toggle for igangvaerende visualization-cache-opdatering. Forhindrer
#' samtidige cache-rebuilds (mod_spc_chart_state).
#'
#' @param app_state Centralized app state
#' @param value Logical TRUE/FALSE
#'
#' @keywords internal
set_viz_cache_updating <- function(app_state, value) {
  shiny::isolate({
    app_state$visualization$cache_updating <- value
  })
}

#' Set Session Peek Result
#'
#' Sets the localStorage peek result (has_payload + metadata) used i
#' landing-page restore-card (Issue #193).
#'
#' @param app_state Centralized app state
#' @param value List med has_payload (logical) og evt. metadata-felter
#'
#' @keywords internal
set_session_peek_result <- function(app_state, value) {
  shiny::isolate({
    app_state$session$peek_result <- value
  })
}

# ============================================================================
# H1 ADDITIONS — accessor-disciplin færdiggørelse (#447)
# ============================================================================

#' Set Autogen Active Flag
#'
#' Suspend-flag der signalerer at en programmatisk input-update er undervejs
#' (mod_export_analysis), så settings_save ikke gemmer auto-tekst som
#' bruger-ændring. Ryddes via session$onFlushed.
#'
#' @param app_state Centralized app state
#' @param value Logical TRUE/FALSE
#'
#' @keywords internal
set_autogen_active <- function(app_state, value) {
  shiny::isolate({
    app_state$session$autogen_active <- value
  })
}

#' Get Autogen Active Flag
#'
#' @param app_state Centralized app state
#'
#' @return Logical (default FALSE)
#'
#' @keywords internal
is_autogen_active <- function(app_state) {
  shiny::isolate(isTRUE(app_state$session$autogen_active))
}

#' Get/Set Has-Data Status
#'
#' Wizard-gate-status: "true"/"false"-streng (renderText-kompatibel) der
#' signalerer om der er meningsfuld data tilgængelig.
#'
#' @param app_state Centralized app state
#' @param value "true" eller "false"
#'
#' @keywords internal
get_has_data_status <- function(app_state) {
  shiny::isolate(app_state$session$has_data_status %||% "false")
}

#' @rdname get_has_data_status
#' @keywords internal
set_has_data_status <- function(app_state, value) {
  shiny::isolate({
    app_state$session$has_data_status <- value
  })
}

#' Get/Set Last Save Time
#'
#' Timestamp for seneste vellykket localStorage save (Issue #193).
#'
#' @param app_state Centralized app state
#' @param value POSIXct timestamp (default `Sys.time()`)
#'
#' @keywords internal
get_last_save_time <- function(app_state) {
  shiny::isolate(app_state$session$last_save_time)
}

#' @rdname get_last_save_time
#' @keywords internal
set_last_save_time <- function(app_state, value = Sys.time()) {
  shiny::isolate({
    app_state$session$last_save_time <- value
  })
}

#' Get/Set Auto-Save Enabled
#'
#' Feature-flag for automatisk session-persistering. Sættes til FALSE
#' hvis localStorage er fuldt (quota-fejl).
#'
#' @param app_state Centralized app state
#' @param value Logical TRUE/FALSE
#'
#' @keywords internal
is_auto_save_enabled <- function(app_state) {
  shiny::isolate(app_state$session$auto_save_enabled %||% TRUE)
}

#' @rdname is_auto_save_enabled
#' @keywords internal
set_auto_save_enabled <- function(app_state, value) {
  shiny::isolate({
    app_state$session$auto_save_enabled <- value
  })
}

#' Get/Set Last Upload Time
#'
#' Timestamp for seneste vellykket file-upload. Bruges af rate-limit-
#' check i fct_file_operations.
#'
#' @param app_state Centralized app state
#' @param value POSIXct timestamp (default `Sys.time()`)
#'
#' @keywords internal
get_last_upload_time <- function(app_state) {
  shiny::isolate(app_state$session$last_upload_time)
}

#' @rdname get_last_upload_time
#' @keywords internal
set_last_upload_time <- function(app_state, value = Sys.time()) {
  shiny::isolate({
    app_state$session$last_upload_time <- value
  })
}

#' Set Table Operation Cleanup Needed Flag
#'
#' Markerer at en table-opdatering kræver post-flush cleanup (clearing
#' table_operation_in_progress flag). Forhindrer race conditions
#' mellem rapid table-edits.
#'
#' @param app_state Centralized app state
#' @param value Logical TRUE/FALSE
#'
#' @keywords internal
set_table_op_cleanup_needed <- function(app_state, value) {
  shiny::isolate({
    app_state$data$table_operation_cleanup_needed <- value
  })
}

#' Set Visualization Module Data Cache
#'
#' Atomisk update af både module_data_cache og module_cached_data — disse
#' to skal altid være synkrone for at undgå inkonsistens mellem modulets
#' interne snapshot og UI-readable cache (mod_spc_chart_state).
#'
#' @param app_state Centralized app state
#' @param data Data frame eller NULL
#'
#' @keywords internal
set_module_data_cache <- function(app_state, data) {
  shiny::isolate({
    app_state$visualization$module_data_cache <- data
    app_state$visualization$module_cached_data <- data
  })
}
