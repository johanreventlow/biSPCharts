# ==============================================================================
# mod_spc_chart_state.R
# ==============================================================================
# DATA MANAGEMENT MODULE FOR SPC CHART VISUALIZATION
#
# Purpose: Centralized data loading, filtering, and caching for the SPC chart
#          module. Handles all data-related state management and provides the
#          primary data reactive that other modules depend on.
#
# Extracted from: mod_spc_chart_server.R (Stage 1 of Phase 2c refactoring)
# Depends on: app_state (centralized Shiny state), log_debug, safe_operation
# ==============================================================================

#' Safe Maximum Calculation with Edge Case Handling
#'
#' Calculates the maximum value of a numeric vector, safely handling empty
#' vectors, all-NA values, and infinite results.
#'
#' @param x Numeric vector
#' @param na.rm Logical - remove NA values before calculation (default: TRUE)
#'
#' @return Numeric value (max) or NA_real_ if edge case encountered
#'
#' @details
#' This helper prevents crashes from edge cases:
#' - Empty vectors → NA_real_ (not Inf)
#' - All-NA vectors → NA_real_ (not Inf)
#' - Infinite results → NA_real_ (prevents invalid chart limits)
#'
#' @keywords internal
safe_max <- function(x, na.rm = TRUE) {
  if (length(x) == 0) {
    log_debug("safe_max: empty vector", .context = "VISUALIZATION")
    return(NA_real_)
  }
  if (all(is.na(x))) {
    log_debug("safe_max: all NA values", .context = "VISUALIZATION")
    return(NA_real_)
  }
  result <- max(x, na.rm = na.rm)
  if (is.infinite(result)) {
    log_debug(paste("safe_max: infinite result, returning NA. Input:", paste(x, collapse = ", ")), "VISUALIZATION")
    return(NA_real_)
  }
  return(result)
}

#' Count Outliers in Latest Part of qic_data
#'
#' Beregner antal outliers (`sigma.signal == TRUE`) inden for seneste part af
#' `qic_data`. Matcher BFHcharts' `bfh_extract_spc_stats.bfh_qic_result()` så
#' trin 2 value box ("OBS. UDEN FOR KONTROLGRÆNSE") og trin 3 Typst-tabel
#' viser samme tal.
#'
#' Ved phases/skift filtreres til rækker med `part == max(part)`. Uden `part`
#' kolonne tælles hele datasættet.
#'
#' @param qic_data Data frame fra qicharts2 med `sigma.signal` og evt. `part`.
#'
#' @return Integer med antal outliers, eller 0L hvis `sigma.signal` mangler.
#'
#' @keywords internal
count_outliers_latest_part <- function(qic_data) {
  if (is.null(qic_data) || nrow(qic_data) == 0 ||
    !"sigma.signal" %in% names(qic_data)) {
    return(0L)
  }

  qd <- qic_data
  if ("part" %in% names(qd)) {
    latest_part <- max(qd$part, na.rm = TRUE)
    qd <- qd[qd$part == latest_part, ]
  }

  as.integer(sum(qd$sigma.signal, na.rm = TRUE))
}

#' Get Filtered Module Data
#'
#' Retrieves and filters the current data from app_state, applying:
#' - NULL check
#' - Non-empty row filtering
#' - hide_anhoej_rules attribute assignment
#'
#' @param app_state Reactive values object containing data state
#'
#' @return Data frame (filtered) with hide_anhoej_rules attribute, or NULL
#'
#' @details
#' Uses isolate() to safely access reactive values outside reactive context.
#' Filters rows where all columns are NA. Preserves hide_anhoej_rules setting.
#'
#' @keywords internal
get_module_data <- function(app_state) {
  # Use shiny::isolate() to safely access reactive values
  current_data_check <- shiny::isolate(app_state$data$current_data)
  if (is.null(current_data_check)) {
    return(NULL)
  }

  data <- current_data_check

  # Add hide_anhoej_rules flag as attribute
  hide_anhoej_rules_check <- shiny::isolate(app_state$ui$hide_anhoej_rules)
  attr(data, "hide_anhoej_rules") <- hide_anhoej_rules_check

  # Filter non-empty rows
  non_empty_rows <- apply(data, 1, function(row) any(!is.na(row)))

  if (any(non_empty_rows)) {
    filtered_data <- data[non_empty_rows, ]
    attr(filtered_data, "hide_anhoej_rules") <- hide_anhoej_rules_check
    return(filtered_data)
  } else {
    attr(data, "hide_anhoej_rules") <- hide_anhoej_rules_check
    return(data)
  }
}

#' Initialize Visualization Module State
#'
#' Sets up data caching infrastructure in app_state for the visualization module.
#' Creates null-safe initialization of module_cached_data and module_data_cache.
#'
#' @param app_state Reactive values object
#'
#' @return NULL (side effect: initializes app_state)
#'
#' @keywords internal
initialize_spc_chart_state <- function(app_state) {
  # Initialize module data cache in app_state if not already present
  # Use isolate() to safely check reactive value outside reactive context
  if (is.null(shiny::isolate(app_state$visualization$module_cached_data)) &&
    is.null(shiny::isolate(app_state$visualization$module_data_cache))) {
    set_module_data_cache(app_state, NULL)
  }

  # Initialize consolidated event if not exists
  if (is.null(shiny::isolate(app_state$events$visualization_update_needed))) {
    app_state$events$visualization_update_needed <- 0L
  }

  # Initialize data at startup if available
  if (!is.null(shiny::isolate(app_state$data$current_data))) {
    set_module_data_cache(app_state, get_module_data(app_state))
  }
}

#' Create Module Data Reactive
#'
#' Returns a reactive expression that reads filtered data from cache,
#' updated by the data update observer. Implements cache-based approach
#' to prevent circular reactive dependencies.
#'
#' @param app_state Reactive values object
#'
#' @return Reactive expression returning data frame or NULL
#'
#' @details
#' The actual data update is handled by observeEvent on visualization_update_needed.
#' This reactive only reads from the cache to avoid circular dependencies.
#' Reactivity depends on navigation_changed event to ensure UI updates even
#' when data hasn't changed (e.g., after tab switch).
#'
#' @keywords internal
create_module_data_reactive <- function(app_state) {
  shiny::reactive({
    # React only to navigation for UI updates
    app_state$events$navigation_changed

    # Return cached data (updated atomically by observer in mod_spc_chart_observers.R)
    return(shiny::isolate(app_state$visualization$module_cached_data))
  })
}

#' Register Module Data Update Observer
#'
#' Sets up the observeEvent that updates module data cache when
#' visualization_update_needed event fires. Implements atomic updates
#' with guard flags to prevent race conditions.
#'
#' @param app_state Reactive values object
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#'
#' @return NULL (side effect: registers observer)
#'
#' @keywords internal
register_module_data_observer <- function(app_state, input, output, session) {
  state_flag <- function(value, default = FALSE) {
    if (is.null(value) || length(value) == 0 || anyNA(value)) {
      return(default)
    }
    isTRUE(value[[1]])
  }

  shiny::observeEvent(
    app_state$events$visualization_update_needed,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$DATA_PROCESSING,
    {
      # Level 3: ATOMIC check-and-set with error recovery
      # Check and set must happen in single isolate() block
      currently_updating <- tryCatch(
        {
          shiny::isolate({
            was_updating <- state_flag(app_state$visualization$cache_updating)
            if (!was_updating) {
              set_viz_cache_updating(app_state, TRUE)
            }
            was_updating
          })
        },
        error = function(e) {
          # Emergency cleanup if atomic operation fails
          log_error(paste("Atomic cache flag operation failed:", e$message), "VISUALIZATION")
          set_viz_cache_updating(app_state, FALSE)
          return(TRUE) # Block this update attempt
        }
      )

      if (currently_updating) {
        log_debug("Skipping visualization cache update - already in progress", .context = "VISUALIZATION")
        return()
      }

      # Level 3: Skip if data processing is in progress
      if (state_flag(shiny::isolate(app_state$data$updating_table))) {
        # Reset flag if we're bailing out
        set_viz_cache_updating(app_state, FALSE)
        log_debug("Skipping visualization cache update - table update in progress", .context = "VISUALIZATION")
        return()
      }

      # Level 2: Atomic state update with guard flag
      safe_operation(
        operation_name = "Update visualization cache (Module: state)",
        code = {
          # Guard flag already set atomically above

          on.exit(
            {
              # Clear guard flag on function exit (success or error)
              set_viz_cache_updating(app_state, FALSE)
            },
            add = TRUE
          )

          # Get fresh data
          result_data <- get_module_data(app_state)

          # Atomic cache update - both values updated together
          set_module_data_cache(app_state, result_data)

          data_info <- if (!is.null(result_data)) {
            paste("rows:", nrow(result_data), "cols:", ncol(result_data))
          } else {
            "NULL"
          }

          log_debug(paste("Visualization cache updated atomically:", data_info), "VISUALIZATION")
        },
        fallback = function(e) {
          log_error(paste("Visualization cache update failed:", e$message), "VISUALIZATION")
          # Guard flag cleared by on.exit() even in error case
        },
        error_type = "processing"
      )
    }
  )
}
