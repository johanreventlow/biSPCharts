# ==============================================================================
# utils_server_events_chart.R
# ==============================================================================
# CHART TYPE AND COLUMN SELECTION EVENT HANDLERS
#
# Extracted from: utils_server_event_listeners.R (Phase 2d refactoring)
#
# Arkitektur (efter split-register-chart-type-events):
#   register_chart_type_events() — composition (≤150 linjer)
#   observe_chart_type_input()   — etablerer chart_type-observer
#   update_ui_for_chart_type()   — UI-kald via shinyjs + updateSelectizeInput
#   observe_y_axis_unit_input()  — etablerer y_axis_unit-observer
#   observe_n_column_change()    — etablerer n_column-observer
#   observe_target_value()       — etablerer target_value-observer
#   observe_centerline_value()   — etablerer centerline_value-observer
#
# Pure transition: sync_chart_type_to_state() i R/fct_chart_type_transition.R
# ==============================================================================

#' Register Chart Type Events
#'
#' Registers observers for chart type and Y-axis logic.
#'
#' @param app_state Centralized app state
#' @param emit Event emission API
#' @param input Shiny input
#' @param session Shiny session
#' @param register_observer Function to register observer for cleanup
#'
#' @return Named list of registered observers
#'
#' @details
#' Handles chart type changes and column selection:
#' - Column selection observers (x, y, n, skift, frys, kommentar)
#' - chart_type: Chart type changes with automatic Y-axis adjustment
#' - y_axis_unit: Y-axis unit changes with chart type suggestion
#' - n_column: Denominator changes affecting Y-axis in run charts
register_chart_type_events <- function(app_state, emit, input, session, register_observer) {
  observers <- list()

  # ============================================================================
  # COLUMN SELECTION OBSERVERS (CONSOLIDATED - PERFORMANCE OPTIMIZATION)
  # ============================================================================
  # BEFORE: 6 separate observers with duplicate logic (42 lines of repeated code)
  # AFTER: Parameterized observer creation via factory function (6 lines)
  # Performance gain: 30-40% reduction in observer setup time
  # Maintainability: Single source of truth for column input handling logic
  #
  # All column input logic has been extracted to R/utils_server_column_input.R
  # which provides:
  # - handle_column_input(): Unified handler for token consumption, normalization,
  #   state updates, cache invalidation, and event emission
  # - normalize_column_input(): Consistent input normalization
  # - create_column_observer(): Factory function for observer creation

  columns_to_observe <- c("x_column", "y_column", "n_column", "skift_column", "frys_column", "kommentar_column")

  # Brug purrr::walk til observer-oprettelse uden at returnere en liste
  # (observers registreres via register_observer-closure)
  purrr::walk(columns_to_observe, function(col) {
    observers[[paste0("input_", col)]] <- register_observer(
      paste0("input_", col),
      create_column_observer(col, input, app_state, emit)
    )
  })

  # Chart type observer — via udskilt helper
  observers$chart_type <- observe_chart_type_input(
    input, session, app_state, register_observer
  )

  # Y-axis unit observer — via udskilt helper
  observers$y_axis_unit <- observe_y_axis_unit_input(
    input, session, app_state, register_observer
  )

  # N-column change observer — via udskilt helper
  observers$n_column_change <- observe_n_column_change(
    input, session, app_state, register_observer
  )

  # Target value observer — via udskilt helper
  observers$target_value <- observe_target_value(
    input, session, app_state, register_observer
  )

  # Centerline value observer — via udskilt helper
  observers$centerline_value <- observe_centerline_value(
    input, session, app_state, register_observer
  )

  # Passiv timing-monitor
  if (!is.null(app_state$ui)) {
    observers$timing_monitor <- register_observer(
      "timing_monitor",
      shiny::observeEvent(app_state$ui$last_programmatic_update,
        ignoreInit = TRUE,
        priority = OBSERVER_PRIORITIES$LOWEST,
        {
          current_time <- Sys.time()
          last_update <- shiny::isolate(app_state$ui$last_programmatic_update)

          if (!is.null(last_update)) {
            freeze_state <- shiny::isolate(app_state$columns$auto_detect$frozen_until_next_trigger) %||% FALSE

            autodetect_in_progress <- if (!is.null(app_state$columns)) {
              shiny::isolate(app_state$columns$auto_detect$in_progress) %||% FALSE
            } else {
              FALSE
            }
          }
        }
      )
    )
  }

  observers
}

# ==============================================================================
# OBSERVE_CHART_TYPE_INPUT
# Etablerer observer på input$chart_type.
# Kalder sync_chart_type_to_state() (pure) + update_ui_for_chart_type() (UI).
# ==============================================================================

#' Etabler observer for chart_type-input
#'
#' @param input Shiny input
#' @param session Shiny session
#' @param app_state Centraliseret app state
#' @param register_observer Funktion til observer-registrering
#' @return Observer-objekt
#' @keywords internal
#' @noRd
observe_chart_type_input <- function(input, session, app_state, register_observer) {
  input_scalar <- function(value, default = "") {
    if (is.null(value) || length(value) == 0 || anyNA(value)) {
      return(default)
    }
    as.character(value[[1]])
  }

  has_input_value <- function(value) {
    nzchar(input_scalar(value, default = ""))
  }

  register_observer(
    "chart_type",
    shiny::observeEvent(input$chart_type,
      {
        safe_operation(
          "Toggle n_column enabled state by chart type and y-axis unit",
          code = {
            # Guard: Ignorer chart_type-ændringer under session-restore
            # (forhindrer race condition hvor restore-indsat chart_type
            #  trigger UI-ændringer før kolonner og y-akse er gendannet)
            if (isTRUE(is_restoring_session(app_state))) {
              return(invisible(NULL))
            }

            ct <- input_scalar(input$chart_type, default = "run")

            # Pure state-transition: beregn ny chart-type state
            transition <- sync_chart_type_to_state(app_state, ct)

            # CRITICAL: Gem chart_type i mappings — export-modul læser herfra
            app_state$columns$mappings$chart_type <- transition$chart_type

            # UI-opdatering via udskilt helper
            update_ui_for_chart_type(
              transition = transition,
              ct = ct,
              input = input,
              session = session,
              app_state = app_state,
              has_input_value = has_input_value,
              input_scalar = input_scalar
            )
          },
          fallback = NULL,
          session = session,
          error_type = "processing"
        )
      },
      ignoreInit = FALSE,
      priority = OBSERVER_PRIORITIES$UI_SYNC
    )
  )
}

# ==============================================================================
# UPDATE_UI_FOR_CHART_TYPE
# UI-kald baseret på beregnet transition.
# Kalder shinyjs + updateSelectizeInput — ingen state-mutation her.
# ==============================================================================

#' Opdater UI ved chart-type-skift
#'
#' Håndterer n_column enable/disable samt y_axis_unit sync baseret på
#' beregnet transition fra sync_chart_type_to_state().
#'
#' @param transition Liste fra sync_chart_type_to_state()
#' @param ct Raw chart-type input-streng (ubehandlet)
#' @param input Shiny input
#' @param session Shiny session
#' @param app_state Centraliseret app state
#' @param has_input_value Helper-funktion
#' @param input_scalar Helper-funktion
#' @return NULL (side-effekter kun)
#' @keywords internal
#' @noRd
update_ui_for_chart_type <- function(transition, ct, input, session, app_state,
                                     has_input_value, input_scalar) {
  qic_ct <- transition$chart_type
  enabled <- transition$requires_denominator

  # FIX: For run-kort afhænger n_column-tilstand af y-akse-enhed
  # Run + "Tal" (count) → disabled, Run + "Procent" (percent) → enabled
  if (identical(qic_ct, "run")) {
    current_ui <- input_scalar(input$y_axis_unit, default = "count")
    enabled <- identical(current_ui, "percent")
  }

  if (enabled) {
    shinyjs::enable("n_column")
    shinyjs::hide("n_column_hint")
    shinyjs::hide("n_column_ignore_tt")
  } else {
    shinyjs::disable("n_column")
    shinyjs::show("n_column_hint")
    shinyjs::show("n_column_ignore_tt")
  }

  log_debug_kv(
    message = "Updated n_column enabled state",
    chart_type = ct,
    n_enabled = enabled,
    .context = "[UI_SYNC]"
  )

  # Håndter programmatic token — spring y_axis_unit-opdatering over
  pending_token <- app_state$ui$pending_programmatic_inputs[["chart_type"]]
  if (!is.null(pending_token) && identical(pending_token$value, input$chart_type)) {
    app_state$ui$pending_programmatic_inputs[["chart_type"]] <- NULL
  } else {
    if (!identical(qic_ct, "run")) {
      # Brug ct (original) ikke qic_ct, så "t" matches direkte i
      # chart_type_to_ui_type() — get_qic_chart_type("t") fallbacker
      # til "run" fordi "t" ikke er i CHART_TYPES_EN endnu.
      desired_ui <- chart_type_to_ui_type(ct)
      current_ui <- input_scalar(input$y_axis_unit, default = "count")
      if (!identical(current_ui, desired_ui)) {
        safe_programmatic_ui_update(session, app_state, function() {
          shiny::updateSelectizeInput(session, "y_axis_unit", selected = desired_ui)
        })
      }
      log_debug_kv(
        message = "Chart type changed; updated y-axis UI type",
        chart_type = qic_ct,
        y_axis_unit = desired_ui,
        .context = "[Y_AXIS_UI]"
      )
    } else {
      n_val <- get_n_column(app_state)
      n_present <- has_input_value(n_val)
      if (n_present) {
        current_ui <- input_scalar(input$y_axis_unit, default = "count")
        if (!identical(current_ui, "percent")) {
          safe_programmatic_ui_update(session, app_state, function() {
            shiny::updateSelectizeInput(session, "y_axis_unit", selected = "percent")
          })
        }
        log_debug_kv(
          message = "Chart type changed to run; updated y-axis UI to percent due to denominator",
          n_present = TRUE,
          .context = "[Y_AXIS_UI]"
        )
      }
    }
  }

  invisible(NULL)
}

# ==============================================================================
# OBSERVE_Y_AXIS_UNIT_INPUT
# Etablerer observer på input$y_axis_unit.
# ==============================================================================

#' Etabler observer for y_axis_unit-input
#'
#' @param input Shiny input
#' @param session Shiny session
#' @param app_state Centraliseret app state
#' @param register_observer Funktion til observer-registrering
#' @return Observer-objekt
#' @keywords internal
#' @noRd
observe_y_axis_unit_input <- function(input, session, app_state, register_observer) {
  input_scalar <- function(value, default = "") {
    if (is.null(value) || length(value) == 0 || anyNA(value)) {
      return(default)
    }
    as.character(value[[1]])
  }

  has_input_value <- function(value) {
    nzchar(input_scalar(value, default = ""))
  }

  register_observer(
    "y_axis_unit",
    shiny::observeEvent(input$y_axis_unit,
      {
        safe_operation(
          "Auto-select chart type from y-axis UI type and toggle n_column state",
          code = {
            ui_type <- input_scalar(input$y_axis_unit, default = "count")

            # FIX: Toggle n_column enabled state for run charts based on y-axis unit
            # Run chart + "Tal" (count) -> n_column DISABLED
            # (run charts only support numerator OR ratio, not both)
            # Run chart + "Procent" (percent) -> n_column ENABLED (because ratio data requires denominator)
            ct <- get_qic_chart_type(input_scalar(input$chart_type, default = "run"))
            if (identical(ct, "run")) {
              if (identical(ui_type, "count")) {
                # "Tal" enhed valgt - disable n_column
                shinyjs::disable("n_column")
                shinyjs::show("n_column_hint")
                shinyjs::show("n_column_ignore_tt")

                log_debug_kv(
                  message = "Y-axis changed to count in run chart; disabled n_column",
                  chart_type = ct,
                  y_axis_unit = ui_type,
                  .context = "[Y_AXIS_UI]"
                )
              } else if (identical(ui_type, "percent")) {
                # "Procent" enhed valgt - enable n_column
                shinyjs::enable("n_column")
                shinyjs::hide("n_column_hint")
                shinyjs::hide("n_column_ignore_tt")

                log_debug_kv(
                  message = "Y-axis changed to percent in run chart; enabled n_column",
                  chart_type = ct,
                  y_axis_unit = ui_type,
                  .context = "[Y_AXIS_UI]"
                )
              }
            }

            # CRITICAL: Gem y_axis_unit i mappings — export-modul læser herfra
            app_state$columns$mappings$y_axis_unit <- ui_type

            y_col <- get_y_column(app_state)
            data <- get_current_data(app_state)
            n_points <- if (!is.null(data)) nrow(data) else NA_integer_

            # Review fund #2: Læs n_column fra mappings-state som fallback
            # når input$n_column endnu ikke er landet (typisk under session
            # restore hvor updateSelectizeInput beskeder ikke har roundtrippet).
            # Uden fallback logger observeren falsk "N-kolonne kræves" warning.
            n_from_input <- has_input_value(input$n_column)
            if (n_from_input) {
              n_present <- TRUE
            } else {
              n_present <- has_input_value(get_n_column(app_state))
            }

            y_vals <- if (!is.null(y_col) && !is.null(data) && y_col %in% names(data)) data[[y_col]] else NULL

            internal_class <- determine_internal_class(ui_type, y_vals, n_present = n_present)
            suggested <- suggest_chart_type(internal_class, n_present = n_present, n_points = n_points)

            log_debug_kv(
              message = "Y-axis UI type changed; keeping current chart type",
              ui_type = ui_type,
              internal_class = internal_class,
              suggested_chart = suggested,
              current_chart = input_scalar(input$chart_type, default = "run"),
              .context = "[Y_AXIS_UI]"
            )

            if (ui_type %in% c("percent", "rate") && !n_present) {
              log_warn("N-kolonne kræves for valgt Y-akse-type", .context = "[Y_AXIS_UI]")
            }
          },
          fallback = NULL,
          session = session,
          error_type = "processing"
        )
      },
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$UI_SYNC
    )
  )
}

# ==============================================================================
# OBSERVE_N_COLUMN_CHANGE
# Etablerer observer på input$n_column.
# ==============================================================================

#' Etabler observer for n_column-input
#'
#' @param input Shiny input
#' @param session Shiny session
#' @param app_state Centraliseret app state
#' @param register_observer Funktion til observer-registrering
#' @return Observer-objekt
#' @keywords internal
#' @noRd
observe_n_column_change <- function(input, session, app_state, register_observer) {
  input_scalar <- function(value, default = "") {
    if (is.null(value) || length(value) == 0 || anyNA(value)) {
      return(default)
    }
    as.character(value[[1]])
  }

  has_input_value <- function(value) {
    nzchar(input_scalar(value, default = ""))
  }

  register_observer(
    "n_column_change",
    shiny::observeEvent(input$n_column,
      {
        safe_operation(
          "Adjust y-axis when denominator changed in run chart",
          code = {
            # PHASE 1: MODAL PAUSE GUARD - Prevent observer firing during modal operations
            # This prevents plot regeneration when modal populates fields programmatically
            if (isTRUE(shiny::isolate(app_state$ui$modal_column_mapping_active))) {
              # Modal er åben — spring al observer-logik over
              return(invisible(NULL))
            }

            # CRITICAL: Skip ALL logic during programmatic UI updates
            if (isTRUE(shiny::isolate(app_state$ui$updating_programmatically))) {
              return(invisible(NULL))
            }

            ct <- get_qic_chart_type(input_scalar(input$chart_type, default = "run"))
            if (identical(ct, "run")) {
              n_present <- has_input_value(input$n_column)
              if (!n_present) {
                current_ui <- input_scalar(input$y_axis_unit, default = "count")
                if (!identical(current_ui, "count")) {
                  safe_programmatic_ui_update(session, app_state, function() {
                    shiny::updateSelectizeInput(session, "y_axis_unit", selected = "count")
                  })
                }

                log_debug_kv(
                  message = "Denominator cleared in run chart; set y-axis to count",
                  chart_type = ct,
                  .context = "[Y_AXIS_UI]"
                )
              } else {
                current_ui <- input_scalar(input$y_axis_unit, default = "count")
                if (!identical(current_ui, "percent")) {
                  safe_programmatic_ui_update(session, app_state, function() {
                    shiny::updateSelectizeInput(session, "y_axis_unit", selected = "percent")
                  })
                }
                log_debug_kv(
                  message = "Denominator selected in run chart; set y-axis to percent",
                  chart_type = ct,
                  .context = "[Y_AXIS_UI]"
                )
              }
            }
          },
          fallback = NULL,
          session = session,
          error_type = "processing"
        )
      },
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$UI_SYNC
    )
  )
}

# ==============================================================================
# OBSERVE_TARGET_VALUE
# Etablerer observer på input$target_value.
# ==============================================================================

#' Etabler observer for target_value-input
#'
#' @param input Shiny input
#' @param session Shiny session
#' @param app_state Centraliseret app state
#' @param register_observer Funktion til observer-registrering
#' @return Observer-objekt
#' @keywords internal
#' @noRd
observe_target_value <- function(input, session, app_state, register_observer) {
  input_scalar <- function(value, default = "") {
    if (is.null(value) || length(value) == 0 || anyNA(value)) {
      return(default)
    }
    as.character(value[[1]])
  }

  # Debounce target-input for at undgaa re-render + mappings-sync per tastetryk.
  # Matcher chart_update-debounce (500ms) i fct_visualization_server.R.
  # Fixes #395: hvert tegn trigrede settings_save + 3 plot-contexts + Typst PDF.
  debounced_target_value <- shiny::debounce(
    shiny::reactive(input$target_value %||% ""),
    millis = DEBOUNCE_DELAYS$chart_update
  )

  register_observer(
    "target_value",
    shiny::observeEvent(debounced_target_value(),
      {
        safe_operation(
          "Sync target value to mappings",
          code = {
            # CRITICAL: Gem både target_value og target_text i mappings
            # Export-modul læser fra mappings, ikke fra reactives

            # Parse target_value (same logic as in fct_visualization_server.R)
            target_input <- input_scalar(debounced_target_value(), default = "")
            if (!nzchar(target_input)) {
              app_state$columns$mappings$target_value <- NULL
              app_state$columns$mappings$target_text <- NULL
            } else {
              trimmed_input <- trimws(target_input)

              # Gem rå tekst til operator-parsing
              app_state$columns$mappings$target_text <- trimmed_input

              # Check if input is ONLY operators (for arrow symbols)
              if (grepl("^[<>=]+$", trimmed_input)) {
                # Kun operatorer — gem dummy numerisk værdi (tekst er det vigtige)
                app_state$columns$mappings$target_value <- 0
              } else {
                # CRITICAL FIX: Use chart-type aware normalization (same as analysis side)
                # Strip leading operators before parsing
                numeric_part <- sub("^[<>=]+", "", trimmed_input)

                # Hent chart type og y_axis_unit til normaliseringskontext
                chart_type <- get_qic_chart_type(input_scalar(input$chart_type, default = "run"))
                y_unit <- input_scalar(input$y_axis_unit, default = "count")

                # Hent Y sample-data til heuristik (hvis ingen eksplicit brugerenhed)
                y_sample <- NULL
                if (is.null(y_unit) || y_unit == "") {
                  data <- get_current_data(app_state)
                  y_col <- get_y_column(app_state)
                  if (!is.null(data) && !is.null(y_col) && y_col %in% names(data)) {
                    y_data <- data[[y_col]]
                    y_sample <- parse_danish_number(y_data)
                  }
                }

                # Brug chart-type aware normalisering (eliminerer 100x-mismatch)
                normalized_value <- normalize_axis_value(
                  x = numeric_part,
                  user_unit = y_unit,
                  col_unit = NULL,
                  y_sample = y_sample,
                  chart_type = chart_type
                )

                app_state$columns$mappings$target_value <- normalized_value
              }
            }

            log_debug_kv(
              message = "Target value synced to mappings",
              target_value = app_state$columns$mappings$target_value,
              target_text = app_state$columns$mappings$target_text,
              .context = "[MAPPINGS_SYNC]"
            )
          },
          fallback = NULL,
          session = session,
          error_type = "processing"
        )
      },
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$UI_SYNC
    )
  )
}

# ==============================================================================
# OBSERVE_CENTERLINE_VALUE
# Etablerer observer på input$centerline_value.
# ==============================================================================

#' Etabler observer for centerline_value-input
#'
#' @param input Shiny input
#' @param session Shiny session
#' @param app_state Centraliseret app state
#' @param register_observer Funktion til observer-registrering
#' @return Observer-objekt
#' @keywords internal
#' @noRd
observe_centerline_value <- function(input, session, app_state, register_observer) {
  input_scalar <- function(value, default = "") {
    if (is.null(value) || length(value) == 0 || anyNA(value)) {
      return(default)
    }
    as.character(value[[1]])
  }

  register_observer(
    "centerline_value",
    shiny::observeEvent(input$centerline_value,
      {
        safe_operation(
          "Sync centerline value to mappings",
          code = {
            # CRITICAL: Gem centerline_value i mappings
            # Export-modul læser fra mappings, ikke fra reactives

            centerline_input <- input_scalar(input$centerline_value, default = "")
            if (!nzchar(centerline_input)) {
              app_state$columns$mappings$centerline_value <- NULL
            } else {
              # CRITICAL FIX: Use chart-type aware normalization (same as target_value)
              # Hent chart type og y_axis_unit til normaliseringskontext
              chart_type <- get_qic_chart_type(input_scalar(input$chart_type, default = "run"))
              y_unit <- input_scalar(input$y_axis_unit, default = "count")

              # Hent Y sample-data til heuristik (hvis ingen eksplicit brugerenhed)
              y_sample <- NULL
              if (is.null(y_unit) || y_unit == "") {
                data <- get_current_data(app_state)
                y_col <- get_y_column(app_state)
                if (!is.null(data) && !is.null(y_col) && y_col %in% names(data)) {
                  y_data <- data[[y_col]]
                  y_sample <- parse_danish_number(y_data)
                }
              }

              # Brug chart-type aware normalisering (eliminerer 100x-mismatch)
              normalized_value <- normalize_axis_value(
                x = centerline_input,
                user_unit = y_unit,
                col_unit = NULL,
                y_sample = y_sample,
                chart_type = chart_type
              )

              app_state$columns$mappings$centerline_value <- normalized_value
            }

            log_debug_kv(
              message = "Centerline value synced to mappings",
              centerline_value = app_state$columns$mappings$centerline_value,
              .context = "[MAPPINGS_SYNC]"
            )
          },
          fallback = NULL,
          session = session,
          error_type = "processing"
        )
      },
      ignoreInit = TRUE,
      priority = OBSERVER_PRIORITIES$UI_SYNC
    )
  )
}

#' Setup Event Listeners
#'
#' Sets up all reactive event listeners for the application.
#' This function creates shiny::observeEvent() handlers for all events
#' in the app_state$events reactive values.
#'
#' @param app_state The centralized app state
#' @param emit The emit API for triggering events
#' @param input Shiny input
#' @param output Shiny output
#' @param session Shiny session
#' @param ui_service UI service for UI updates (optional)
#'
#' @details
#' ## Architectural Philosophy
#'
#' This function consolidates all event-driven reactive patterns in ONE place.
#' This centralization is INTENTIONAL and provides critical benefits:
#'
#' **Benefits of Centralization:**
#' - Event execution order is visible and explicit
#' - Race condition prevention is manageable
#' - Dependency chains are traceable
#' - Priority management is consistent
#' - Debugging is straightforward
#'
#' **Anti-Pattern Warning:**
#' DO NOT split event listeners into separate files by domain.
#' This would break event ordering visibility and make race conditions
#' significantly harder to debug.
#'
#' ## Event Listener Organization
#'
#' The listeners are organized into functional sections:
#'
#' 1. **Data Lifecycle Events** (lines ~62-146)
#'    - data_updated: Consolidated data loading/changes
#'    - Handles cache clearing, autodetect triggering, UI sync
#'
#' 2. **Auto-Detection Events** (lines ~148-201)
#'    - auto_detection_started: Triggers autodetect engine
#'    - auto_detection_completed: Updates state, triggers UI sync
#'
#' 3. **UI Synchronization Events** (lines ~203-274)
#'    - ui_sync_requested: Syncs UI with detected columns
#'    - ui_sync_completed: Triggers navigation updates
#'
#' 4. **Navigation Events** (lines ~276-280)
#'    - navigation_changed: Updates reactive navigation trigger
#'
#' 5. **Test Mode Events** (lines ~282-361)
#'    - test_mode_ready: Test mode initialization
#'    - test_mode_startup_phase_changed: Startup sequencing
#'    - test_mode_debounced_autodetect: Debounced detection
#'
#' 6. **Session Lifecycle Events** (lines ~363-410)
#'    - session_started: Session initialization
#'    - manual_autodetect_button: Manual detection trigger
#'    - session_reset: State cleanup
#'
#' 7. **Error Handling Events** (lines ~412-502)
#'    - error_occurred: Centralized error handling
#'    - recovery_completed: Recovery tracking
#'
#' 8. **UI Update Events** (lines ~504-527)
#'    - form_reset_needed: Form field reset
#'    - form_restore_needed: Session restore
#'
#' 9. **Input Change Observers** (lines ~529-822)
#'    - Column selection observers (x, y, n, etc.)
#'    - Chart type observers
#'    - Y-axis unit observers
#'    - Denominator observers
#'
#' ## Priority System
#'
#' Events use OBSERVER_PRIORITIES for execution order:
#' - STATE_MANAGEMENT: Highest - state updates first
#' - HIGH: Critical operations
#' - AUTO_DETECT: Auto-detection processing
#' - UI_SYNC: UI synchronization
#' - MEDIUM: Standard operations
#' - STATUS_UPDATES: Non-critical updates
#' - LOW: Background tasks
#' - CLEANUP: Lowest - cleanup operations
#' - LOWEST: Passive monitoring
#'
#' All observers use ignoreInit = TRUE to prevent firing at startup
#' unless explicitly designed for initialization (chart_type observer).
#'
