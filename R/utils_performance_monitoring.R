# R/utils_performance_monitoring.R
# Performance Monitoring System for SPC App Startup
# Provides metrics for tracking QIC calls and events

# Global performance state
.startup_metrics <- new.env(parent = emptyenv())

#' Initialize startup metrics (internal helper)
#'
#' @keywords internal
.ensure_metrics_initialized <- function() {
  if (!exists("start_time", envir = .startup_metrics)) {
    .startup_metrics$start_time <- Sys.time()
    .startup_metrics$qic_calls <- 0
    .startup_metrics$events_fired <- list()
    .startup_metrics$event_sequence <- list()
  }
}

#' Track QIC function call with context
#'
#' @param context Character. Context where QIC was called
#' @param details List. Additional context information
#' @keywords internal
track_qic_call <- function(context = "unknown", details = list()) {
  .ensure_metrics_initialized()

  .startup_metrics$qic_calls <- .startup_metrics$qic_calls + 1

  call_info <- list(
    call_number = .startup_metrics$qic_calls,
    timestamp = Sys.time(),
    context = context,
    details = details,
    time_since_start = as.numeric(difftime(Sys.time(), .startup_metrics$start_time, units = "secs"))
  )

  if (!exists("qic_call_details", envir = .startup_metrics)) {
    .startup_metrics$qic_call_details <- list()
  }

  .startup_metrics$qic_call_details[[length(.startup_metrics$qic_call_details) + 1]] <- call_info

  log_debug(
    paste("QIC call", .startup_metrics$qic_calls, "tracked - context:", context),
    "PERFORMANCE_MONITORING"
  )
}

#' Track event firing
#'
#' @param event_name Character. Name of the event
#' @param context Character. Context where event was fired
#' @keywords internal
track_event <- function(event_name, context = "unknown") {
  .ensure_metrics_initialized()

  event_info <- list(
    event = event_name,
    timestamp = Sys.time(),
    context = context,
    time_since_start = as.numeric(difftime(Sys.time(), .startup_metrics$start_time, units = "secs"))
  )

  # Add to event sequence
  .startup_metrics$event_sequence[[length(.startup_metrics$event_sequence) + 1]] <- event_info

  # Count occurrences per event type
  if (!exists("events_fired", envir = .startup_metrics)) {
    .startup_metrics$events_fired <- list()
  }

  if (is.null(.startup_metrics$events_fired[[event_name]])) {
    .startup_metrics$events_fired[[event_name]] <- 0
  }

  .startup_metrics$events_fired[[event_name]] <- .startup_metrics$events_fired[[event_name]] + 1

  log_debug(paste("Event tracked:", event_name), "PERFORMANCE_MONITORING")
}
