# Session status observers and output helpers.

evaluate_dataLoaded_status <- function(app_state, session = NULL) {
  current_data_check <- app_state$data$current_data

  if (is.null(current_data_check)) {
    return("FALSE")
  }

  meaningful_data <- evaluate_data_content_cached(
    current_data_check,
    session = session,
    invalidate_events = c("data_loaded", "session_reset", "navigation_changed")
  )

  file_uploaded_check <- app_state$session$file_uploaded
  user_started_session_check <- app_state$session$user_started_session
  user_has_started <- file_uploaded_check || user_started_session_check %||% FALSE

  log_debug_kv(
    meaningful_data = meaningful_data,
    file_uploaded_check = file_uploaded_check,
    user_started_session_check = user_started_session_check,
    user_has_started = user_has_started,
    .context = "NAVIGATION_UNIFIED"
  )

  if (meaningful_data || user_has_started) "TRUE" else "FALSE"
}

evaluate_has_data_status <- function(app_state, session = NULL) {
  current_data_check <- app_state$data$current_data

  if (is.null(current_data_check)) {
    return("false")
  }

  meaningful_data <- evaluate_data_content_cached(
    current_data_check,
    session = session,
    invalidate_events = c("data_loaded", "session_reset", "navigation_changed")
  )

  if (meaningful_data) "true" else "false"
}

register_session_status_observers <- function(events, evaluator, setter, priority) {
  observers <- lapply(
    c("data_updated", "session_reset", "navigation_changed"),
    function(event_name) {
      force(event_name)
      shiny::observeEvent(events[[event_name]], ignoreInit = TRUE, priority = priority, {
        setter(evaluator())
      })
    }
  )

  invisible(observers)
}

register_session_status_outputs <- function(output, session, app_state) {
  if (is.null(shiny::isolate(app_state$session$dataLoaded_status))) {
    app_state$session$dataLoaded_status <- "FALSE"
  }

  data_loaded_evaluator <- function() evaluate_dataLoaded_status(app_state, session)
  register_session_status_observers(
    events = app_state$events,
    evaluator = data_loaded_evaluator,
    setter = function(value) app_state$session$dataLoaded_status <- value,
    priority = OBSERVER_PRIORITIES$DATA_PROCESSING
  )

  output$dataLoaded <- shiny::renderText(app_state$session$dataLoaded_status)
  outputOptions(output, "dataLoaded", suspendWhenHidden = FALSE)

  if (is.null(shiny::isolate(app_state$session$has_data_status))) {
    set_has_data_status(app_state, "false")
  }

  has_data_evaluator <- function() evaluate_has_data_status(app_state, session)
  register_session_status_observers(
    events = app_state$events,
    evaluator = has_data_evaluator,
    setter = function(value) set_has_data_status(app_state, value),
    priority = OBSERVER_PRIORITIES$DATA_PROCESSING
  )

  shiny::observeEvent(TRUE, once = TRUE, priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT, {
    app_state$session$dataLoaded_status <- data_loaded_evaluator()
    set_has_data_status(app_state, has_data_evaluator())
  })

  output$has_data <- shiny::renderText(app_state$session$has_data_status)
  outputOptions(output, "has_data", suspendWhenHidden = FALSE)
}
