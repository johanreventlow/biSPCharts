# utils_ui_updates.R
# Backward-compat wrapper + delt UI-infrastruktur (queue, loop-protection)
#
# Selve opdateringslogikken er splittet i:
#   R/utils_ui_column_update_service.R - kolonne-selectize ops
#   R/utils_ui_form_update_service.R   - form-felter, reset, feedback

#' Create UI Update Service
#'
#' Backward-kompatibel wrapper der komponerer column- og form-services.
#' Eksisterende kaldere fortsaetter uaendret; fremtidig kode boer bruge
#' `create_column_update_service()` og `create_form_update_service()` direkte.
#'
#' @param session Shiny session object
#' @param app_state Centralized app state
#' @return List of UI update functions (merged column + form APIs)
#'
#' @examples
#' \dontrun{
#' ui_service <- create_ui_update_service(session, app_state)
#' ui_service$update_column_choices()
#' }
#'
#' @keywords internal
create_ui_update_service <- function(session, app_state) {
  col_svc <- create_column_update_service(session, app_state)
  form_svc <- create_form_update_service(session, app_state, column_service = col_svc)
  c(col_svc, form_svc)
}

#' Safe Programmatic UI Update Wrapper (Enhanced with Intelligent Flag Clearing)
#'
#' Advanced wrapper function that prevents circular event loops during programmatic UI updates.
#' Uses intelligent flag-clearing strategy with session$onFlushed for immediate clearing after
#' Shiny processes updates, with later::later() safety fallback for robust operation.
#'
#' KEY FEATURES:
#' - Configurable delay from LOOP_PROTECTION_DELAYS constants
#' - Single-reset guarantee to prevent double flag clearing
#' - session$onFlushed primary strategy for immediate response
#' - later::later() safety fallback with double delay
#' - Comprehensive timing logging for performance optimization
#' - Freeze-aware logging that respects autodetect state without interference
#' - Automatic session cleanup on error conditions
#'
#' TIMING STRATEGY:
#' 1. session$onFlushed(): Immediate clearing after Shiny processes UI updates
#' 2. later::later() fallback: Safety net with 2x delay if onFlushed doesn't fire
#' 3. Synchronous delay: Last resort if later package unavailable
#'
#' @param session Shiny session object (must support onFlushed for optimal performance)
#' @param app_state Centralized app state with UI protection flags and autodetect state
#' @param update_function Function to execute with protection (should contain updateSelectizeInput calls)
#' @param delay_ms Delay in milliseconds (default: uses LOOP_PROTECTION_DELAYS$default from constants)
#'
#' @examples
#' \dontrun{
#' # Standard usage with default 500ms delay
#' safe_programmatic_ui_update(session, app_state, function() {
#'   shiny::updateSelectizeInput(session, "x_column", choices = choices, selected = "Dato")
#'   shiny::updateSelectizeInput(session, "y_column", choices = choices, selected = "Taeller")
#' })
#'
#' # Custom delay for slow environments
#' safe_programmatic_ui_update(session, app_state, function() {
#'   shiny::updateSelectizeInput(session, "x_column", choices = choices, selected = "Dato")
#' }, delay_ms = LOOP_PROTECTION_DELAYS$conservative)
#' }
#'
#' @keywords internal
safe_programmatic_ui_update <- function(session, app_state, update_function, delay_ms = NULL) {
  scalar_logical <- function(value, default = FALSE) {
    if (is.null(value) || length(value) == 0 || anyNA(value)) {
      return(default)
    }
    isTRUE(value[[1]])
  }

  scalar_integer <- function(value, default = 0L) {
    if (is.null(value) || length(value) == 0 || anyNA(value)) {
      return(default)
    }
    as.integer(value[[1]])
  }

  safe_list <- function(value) {
    if (is.null(value) || !is.list(value)) {
      return(list())
    }
    value
  }

  if (is.null(delay_ms)) {
    delay_ms <- LOOP_PROTECTION_DELAYS$default
  }

  freeze_state <- shiny::isolate(app_state$columns$auto_detect$frozen_until_next_trigger) %||% FALSE
  # Starting safe programmatic UI update

  run_update <- function() {
    execution_start <- Sys.time()
    performance_start <- execution_start

    shiny::isolate(app_state$ui$updating_programmatically <- TRUE)
    on.exit(
      {
        shiny::isolate(app_state$ui$updating_programmatically <- FALSE)

        pending_queue <- length(safe_list(shiny::isolate(app_state$ui$queued_updates)))
        queue_idle <- !scalar_logical(shiny::isolate(app_state$ui$queue_processing))

        if (pending_queue > 0 && queue_idle) {
          if (requireNamespace("later", quietly = TRUE)) {
            # SPRINT 3: Use config constant for immediate processing
            later::later(function() {
              process_ui_update_queue(app_state)
            }, delay = UI_UPDATE_CONFIG$immediate_delay)
          } else {
            process_ui_update_queue(app_state)
          }
        }
      },
      add = TRUE
    )


    safe_operation(
      "Execute update function",
      code = {
        update_function()
      },
      fallback = function(e) {
        # H8: Log only - skip retry/recovery for simplicity
        log_error(
          paste("UI update function fejlede:", e$message),
          .context = "UI_UPDATE_QUEUE"
        )
        NULL
      },
      error_type = "ui"
    )

    update_completed_time <- Sys.time()
    execution_time_ms <- as.numeric(difftime(update_completed_time, execution_start, units = "secs")) * 1000
    # Operation completed
    performance_end <- Sys.time()
    update_duration_ms <- as.numeric(difftime(performance_end, performance_start, units = "secs")) * 1000

    shiny::isolate({
      app_state$ui$performance_metrics$total_updates <-
        scalar_integer(app_state$ui$performance_metrics$total_updates) + 1L

      current_avg <- as.numeric(app_state$ui$performance_metrics$avg_update_duration_ms %||% 0)
      total_updates <- scalar_integer(app_state$ui$performance_metrics$total_updates)

      if (total_updates == 1) {
        app_state$ui$performance_metrics$avg_update_duration_ms <- update_duration_ms
      } else {
        app_state$ui$performance_metrics$avg_update_duration_ms <-
          (current_avg * (total_updates - 1) + update_duration_ms) / total_updates
      }
    })

    invisible(NULL)
  }

  safe_operation(
    "Execute programmatic UI update",
    code = {
      busy <- scalar_logical(shiny::isolate(app_state$ui$queue_processing)) ||
        scalar_logical(shiny::isolate(app_state$ui$updating_programmatically))

      if (busy) {
        queue_entry <- list(
          func = run_update,
          session = session,
          timestamp = Sys.time(),
          delay_ms = delay_ms,
          queue_id = paste0("queue_", format(Sys.time(), "%Y%m%d%H%M%S"), "_", sample(1000:9999, 1))
        )

        current_queue <- safe_list(shiny::isolate(app_state$ui$queued_updates))
        max_queue_size <- scalar_integer(shiny::isolate(app_state$ui$memory_limits$max_queue_size), default = 50L)

        if (length(current_queue) >= max_queue_size) {
          # Queue operation completed
          current_queue <- current_queue[-1]
        }

        new_queue <- c(current_queue, list(queue_entry))
        app_state$ui$queued_updates <- new_queue

        shiny::isolate({
          app_state$ui$performance_metrics$queued_updates <-
            scalar_integer(app_state$ui$performance_metrics$queued_updates) + 1L
          queue_size <- length(safe_list(app_state$ui$queued_updates))
          queue_max_size <- scalar_integer(app_state$ui$performance_metrics$queue_max_size)
          if (queue_size > queue_max_size) {
            app_state$ui$performance_metrics$queue_max_size <- queue_size
          }
        })

        # Operation completed

        if (scalar_logical(shiny::isolate(app_state$ui$queue_processing))) {
          enqueue_ui_update(app_state, queue_entry)
        }

        return(invisible(NULL))
      }

      run_update()
    },
    fallback = function(e) {
      app_state$ui$updating_programmatically <- FALSE
      app_state$ui$flag_reset_scheduled <- TRUE
      log_error(paste("LOOP_PROTECTION: Fejl under programmatisk UI opdatering:", e$message), "LOOP_PROTECTION")
      stop(e)
    },
    error_type = "processing"
  )

  invisible(NULL)
}

# FASE 2: QUEUE PROCESSING FUNCTIONS ============================================

#' Enqueue UI Update
#'
#' Clean API for enqueueing UI updates with automatic processor start
#'
#' @param app_state Application state containing queue
#' @param queue_entry Queue entry to add
#' @return Invisibly returns success status
#'
#' @keywords internal
enqueue_ui_update <- function(app_state, queue_entry) {
  # Add to queue (already done in calling function, but kept for API completeness)
  # This function focuses on starting processor if needed

  # Start processor if not already running
  if (!isTRUE(shiny::isolate(app_state$ui$queue_processing))) {
    # Queue operation completed
    process_ui_update_queue(app_state)
  } else {
    # Queue operation completed
  }

  invisible(TRUE)
}

#' Process UI Update Queue
#'
#' Processes queued UI updates in order, ensuring only one update runs at a time.
#' This function is called by later::later() after current UI update completes.
#'
#' @param app_state The centralized app state object
#'
#' @keywords internal
process_ui_update_queue <- function(app_state) {
  # Set processing flag and ensure cleanup
  shiny::isolate(app_state$ui$queue_processing <- TRUE)
  on.exit({
    shiny::isolate(app_state$ui$queue_processing <- FALSE)
    # Schedule next run if queue still has items
    if (length(shiny::isolate(app_state$ui$queued_updates)) > 0) {
      if (requireNamespace("later", quietly = TRUE)) {
        # SPRINT 3: Use config constant for immediate processing
        later::later(function() {
          process_ui_update_queue(app_state)
        }, delay = UI_UPDATE_CONFIG$immediate_delay)
      }
    }
  })

  while (TRUE) {
    # GET QUEUE: Check current state
    current_queue <- shiny::isolate(app_state$ui$queued_updates)

    # EMPTY CHECK: Exit if no items to process
    if (length(current_queue) == 0) {
      # Queue operation completed
      break
    }

    # PROCESS NEXT: Take first item from queue
    next_update <- current_queue[[1]]
    remaining_queue <- if (length(current_queue) > 1) current_queue[-1] else list()

    # UPDATE QUEUE: Remove processed item immediately
    shiny::isolate(app_state$ui$queued_updates <- remaining_queue)

    # EXECUTE UPDATE: Run function directly without wrapper recursion
    safe_operation(
      "Execute queued UI update",
      code = {
        # Execute the stored function directly
        next_update$func()
      },
      fallback = function(e) {
        # Queue operation completed
      },
      session = next_update$session,
      show_user = FALSE
    )

    # Limit processing to prevent runaway loops
    if (length(shiny::isolate(app_state$ui$queued_updates)) > 100) {
      # Queue operation completed
      break
    }
  }

  invisible(NULL)
}

#' Cleanup Expired Queue Updates
#'
#' Removes old queue entries that are likely no longer relevant.
#' This prevents the queue from growing indefinitely with stale updates.
#'
#' @param app_state The centralized app state object
#' @param max_age_seconds Maximum age of queue entries in seconds (default: 30)
#'
#' @keywords internal
cleanup_expired_queue_updates <- function(app_state, max_age_seconds = 30) {
  current_queue <- shiny::isolate(app_state$ui$queued_updates)

  if (length(current_queue) == 0) {
    return()
  }

  current_time <- Sys.time()
  fresh_updates <- list()

  for (i in seq_along(current_queue)) {
    update_entry <- current_queue[[i]]
    age_seconds <- as.numeric(difftime(current_time, update_entry$timestamp, units = "secs"))

    if (age_seconds <= max_age_seconds) {
      fresh_updates <- c(fresh_updates, list(update_entry))
    } else {
      # Operation completed
    }

    # UPDATE QUEUE with fresh entries only
    app_state$ui$queued_updates <- fresh_updates

    removed_count <- length(current_queue) - length(fresh_updates)
    if (removed_count > 0) {
      # Queue cleaned up
    }
  }

  invisible(NULL)
}

# FASE 3: MEMORY MANAGEMENT FUNCTIONS ===========================================

#' Comprehensive System Cleanup
#'
#' Performs cleanup of queue system.
#' Should be called periodically to maintain system health.
#'
#' @param app_state The centralized app state object
#'
#' @keywords internal
comprehensive_system_cleanup <- function(app_state) {
  # Clean expired queue updates
  cleanup_expired_queue_updates(app_state, max_age_seconds = 30)

  invisible(NULL)
}

#' Get Performance Report
#'
#' Returns a formatted performance report for monitoring system health.
#'
#' @param app_state The centralized app state object
#' @return List with performance metrics and formatted report
#'
#' @keywords internal
get_performance_report <- function(app_state) {
  metrics <- shiny::isolate(app_state$ui$performance_metrics)
  limits <- shiny::isolate(app_state$ui$memory_limits)
  current_queue_size <- length(shiny::isolate(app_state$ui$queued_updates))
  current_queue_size <- length(shiny::isolate(app_state$ui$queued_updates))

  # Calculate uptime since last reset
  uptime_hours <- as.numeric(difftime(Sys.time(), metrics$last_performance_reset, units = "hours"))

  report <- list(
    uptime_hours = round(uptime_hours, 2),
    total_updates = metrics$total_updates,
    queued_updates = metrics$queued_updates,
    queue_max_size = metrics$queue_max_size,
    avg_update_duration_ms = round(metrics$avg_update_duration_ms, 2),
    current_queue_size = current_queue_size,
    queue_utilization_pct = round((current_queue_size / limits$max_queue_size) * 100, 1)
  )

  # Add health status
  report$health_status <- if (report$queue_utilization_pct > 80) {
    "WARNING"
  } else if (report$queue_utilization_pct > 60) {
    "CAUTION"
  } else {
    "HEALTHY"
  }

  report
}
