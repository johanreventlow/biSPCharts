# ==============================================================================
# utils_server_events_autodetect.R
# ==============================================================================
# AUTO-DETECTION EVENT HANDLERS
#
# Extracted from: utils_server_event_listeners.R (Phase 2d refactoring)
# ==============================================================================

#' Register Auto-Detection Events
#'
#' Vis notifikation med auto-detekterede kolonner
#'
#' @param results Liste med x_col, y_col, n_col osv.
#' @param session Shiny session
#' @noRd
notify_autodetect_results <- function(results, session) {
  # Byg liste af fundne kolonner
  mapping_labels <- c(
    x_col = "X-akse",
    y_col = "Y-akse",
    n_col = "N\u00e6vner",
    skift_col = "Skift",
    frys_col = "Frys",
    kommentar_col = "Kommentar"
  )

  detected <- vapply(names(mapping_labels), function(key) {
    val <- results[[key]]
    if (!is.null(val) && nzchar(val)) {
      paste0(mapping_labels[[key]], ": ", val)
    } else {
      NA_character_
    }
  }, character(1))

  detected <- detected[!is.na(detected)]

  if (length(detected) == 0) {
    return(invisible(NULL))
  }

  # Dato-format info
  date_hint <- NULL
  dfi <- results$date_format_info
  if (!is.null(dfi) && !is.null(dfi$format)) {
    # Oversæt R date-format til menneskelæseligt
    fmt_label <- switch(dfi$format,
      "%d-%m-%Y" = "dd-mm-\u00e5\u00e5\u00e5\u00e5",
      "%d/%m/%Y" = "dd/mm/\u00e5\u00e5\u00e5\u00e5",
      "%d.%m.%Y" = "dd.mm.\u00e5\u00e5\u00e5\u00e5",
      "%Y-%m-%d" = "\u00e5\u00e5\u00e5\u00e5-mm-dd",
      "%d-%m-%y" = "dd-mm-\u00e5\u00e5",
      dfi$format
    )
    if (!is.null(dfi$confidence) && dfi$confidence < 0.9) {
      date_hint <- paste0(
        " \u26a0 Datoformat usikkert (", fmt_label,
        ") \u2014 kontroll\u00e9r venligst."
      )
    } else {
      date_hint <- paste0(
        " Datoformat: ", fmt_label
      )
    }
  }

  msg <- paste0(
    "Kolonner detekteret: ",
    paste(detected, collapse = ", "),
    ".",
    if (!is.null(date_hint)) date_hint else ""
  )

  tryCatch(
    shiny::showNotification(
      shiny::tags$span(shiny::icon("magic"), " ", msg),
      type = if (!is.null(dfi) &&
        !is.null(dfi$confidence) &&
        dfi$confidence < 0.9) {
        "warning"
      } else {
        "message"
      },
      duration = if (!is.null(dfi) &&
        !is.null(dfi$confidence) &&
        dfi$confidence < 0.9) {
        10
      } else {
        6
      }
    ),
    error = function(e) invisible(NULL)
  )
}

#' Registers observers for auto-detection processing.
#'
#' @param app_state Centralized app state
#' @param emit Event emission API
#' @param session Shiny session
#' @param register_observer Function to register observer for cleanup
#'
#' @return Named list of registered observers
#'
#' @details
#' Handles all events related to column auto-detection:
#' - auto_detection_started: Triggers autodetect engine
#' - auto_detection_completed: Updates state, triggers UI sync
register_autodetect_events <- function(app_state, emit, session, register_observer) {
  observers <- list()

  observers$auto_detection_started <- register_observer(
    "auto_detection_started",
    shiny::observeEvent(app_state$events$auto_detection_started,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$AUTO_DETECT,
      {
        safe_operation(
          "Auto-detection processing",
          code = {
            if (!is.null(app_state$data$current_data)) {
              # Use unified autodetect engine - data available, so full analysis
              autodetect_engine(
                data = app_state$data$current_data,
                trigger_type = "file_upload",
                app_state = app_state,
                emit = emit
              )
            } else {
              # No data available - session start scenario (name-only)
              autodetect_engine(
                data = NULL,
                trigger_type = "session_start",
                app_state = app_state,
                emit = emit
              )
            }
          },
          fallback = {
            # Only reset in_progress if autodetect_engine didn't handle it
            if (get_autodetect_status(app_state)$in_progress) {
              app_state$columns$auto_detect$in_progress <- FALSE
            }
          },
          session = NULL,
          error_type = "processing",
          emit = emit,
          app_state = app_state
        )
      }
    )
  )

  observers$auto_detection_completed <- register_observer(
    "auto_detection_completed",
    shiny::observeEvent(app_state$events$auto_detection_completed,
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$AUTO_DETECT,
      {
        # Update state
        app_state$columns$auto_detect$in_progress <- FALSE
        app_state$columns$auto_detect$completed <- TRUE

        # Trigger UI sync if columns were detected
        auto_detect_results <- get_autodetect_status(app_state)$results

        if (!is.null(auto_detect_results)) {
          # Vis notifikation med detekterede kolonner
          notify_autodetect_results(auto_detect_results, session)
          emit$ui_sync_needed()
        }
      }
    )
  )

  observers
}
