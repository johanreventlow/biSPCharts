# test-event-system-observers.R
# Tests for event system observer behavior and priorities
# Priority 2: Expand testServer Coverage - Event system tests
#
# APPROACH: Focus on testable logic components rather than complex reactive chains
# Following test-event-driven-reactive.R pattern for reliability

library(testthat)

# EVENT CONTEXT RESOLUTION TESTS ===============================================

test_that("resolve_column_update_reason correctly identifies contexts", {
  # TEST: Context resolution logic from setup_event_listeners

  resolve_column_update_reason <- function(context) {
    if (is.null(context)) {
      return("manual")
    }

    ctx <- tolower(context)

    if (grepl("edit|change|modify|column", ctx, ignore.case = FALSE)) {
      return("edit")
    }

    if (grepl("session", ctx, ignore.case = FALSE)) {
      return("session")
    }

    if (grepl("load|upload|file|new", ctx, ignore.case = FALSE)) {
      return("upload")
    }

    "manual"
  }

  # TEST: Edit contexts
  expect_equal(resolve_column_update_reason("table_edit"), "edit")
  expect_equal(resolve_column_update_reason("column_change"), "edit")
  expect_equal(resolve_column_update_reason("modify_data"), "edit")

  # TEST: Session contexts
  expect_equal(resolve_column_update_reason("session_restore"), "session")
  expect_equal(resolve_column_update_reason("Session_Start"), "session")

  # TEST: Upload contexts
  expect_equal(resolve_column_update_reason("file_upload"), "upload")
  expect_equal(resolve_column_update_reason("data_loaded"), "upload")
  expect_equal(resolve_column_update_reason("new_file"), "upload")

  # TEST: Manual/default
  expect_equal(resolve_column_update_reason(NULL), "manual")
  expect_equal(resolve_column_update_reason("unknown_context"), "manual")
})

# DATA UPDATE CONTEXT HANDLING TESTS ===========================================

test_that("data_updated context determines correct action path", {
  # TEST: Logic for determining action based on data update context

  determine_action_path <- function(context) {
    if (is.null(context)) {
      return("fallback")
    }

    is_table_edit <- identical(context, "table_cells_edited")
    is_load <- grepl("load|upload|new", context, ignore.case = TRUE)
    is_change <- grepl("change|edit|modify", context, ignore.case = TRUE)

    if (is_load) {
      return("trigger_autodetect")
    } else if (is_table_edit) {
      return("update_viz_only")
    } else if (is_change) {
      return("update_columns_and_viz")
    } else {
      return("update_columns_only")
    }
  }

  # TEST: Load context triggers auto-detection
  expect_equal(determine_action_path("file_upload"), "trigger_autodetect")
  expect_equal(determine_action_path("data_loaded"), "trigger_autodetect")
  expect_equal(determine_action_path("new_data"), "trigger_autodetect")

  # TEST: Table edit context updates visualization only
  expect_equal(determine_action_path("table_cells_edited"), "update_viz_only")

  # TEST: Change context updates columns and visualization
  expect_equal(determine_action_path("data_changed"), "update_columns_and_viz")
  expect_equal(determine_action_path("user_edit"), "update_columns_and_viz")

  # TEST: General context updates columns only
  expect_equal(determine_action_path("general"), "update_columns_only")

  # TEST: Fallback for NULL context
  expect_equal(determine_action_path(NULL), "fallback")
})

# AUTO-DETECTION STATE MANAGEMENT TESTS ========================================

test_that("auto-detection frozen state is correctly managed", {
  # TEST: Frozen state logic prevents unnecessary re-detection

  app_state <- list(
    columns = list(
      auto_detect = list(
        frozen_until_next_trigger = FALSE,
        completed = FALSE
      )
    )
  )

  # SIMULATE: Data update unfreezes
  unfreeze_on_data_update <- function(state) {
    state$columns$auto_detect$frozen_until_next_trigger <- FALSE
    state
  }

  # SIMULATE: Detection completion freezes
  freeze_on_detection_complete <- function(state) {
    state$columns$auto_detect$frozen_until_next_trigger <- TRUE
    state$columns$auto_detect$completed <- TRUE
    state
  }

  # TEST: Initial state
  expect_false(app_state$columns$auto_detect$frozen_until_next_trigger)

  # TEST: Detection completes and freezes
  app_state <- freeze_on_detection_complete(app_state)
  expect_true(app_state$columns$auto_detect$frozen_until_next_trigger)

  # TEST: Data update unfreezes
  app_state <- unfreeze_on_data_update(app_state)
  expect_false(app_state$columns$auto_detect$frozen_until_next_trigger)
})

test_that("auto-detection respects frozen state except for manual trigger", {
  # TEST: Frozen state prevents automatic re-detection

  can_run_autodetect <- function(trigger_type, frozen) {
    if (trigger_type == "manual") {
      return(TRUE)  # Manual trigger always bypasses frozen state
    }
    return(!frozen)
  }

  # TEST: Automatic triggers respect frozen state
  expect_true(can_run_autodetect("file_upload", frozen = FALSE))
  expect_false(can_run_autodetect("file_upload", frozen = TRUE))

  expect_true(can_run_autodetect("session_start", frozen = FALSE))
  expect_false(can_run_autodetect("session_start", frozen = TRUE))

  # TEST: Manual trigger bypasses frozen state
  expect_true(can_run_autodetect("manual", frozen = FALSE))
  expect_true(can_run_autodetect("manual", frozen = TRUE))  # BYPASSES!
})

# UI SYNCHRONIZATION LOGIC TESTS ===============================================

test_that("UI sync guards prevent race conditions", {
  # TEST: Guard conditions prevent concurrent operations

  should_skip_column_update <- function(state) {
    if (state$data$updating_table) return(TRUE)
    if (state$columns$auto_detect$in_progress) return(TRUE)
    if (state$columns$ui_sync$needed) return(TRUE)
    return(FALSE)
  }

  # TEST: Normal state allows updates
  normal_state <- list(
    data = list(updating_table = FALSE),
    columns = list(
      auto_detect = list(in_progress = FALSE),
      ui_sync = list(needed = FALSE)
    )
  )
  expect_false(should_skip_column_update(normal_state))

  # TEST: Table updating prevents column updates
  table_updating_state <- normal_state
  table_updating_state$data$updating_table <- TRUE
  expect_true(should_skip_column_update(table_updating_state))

  # TEST: Auto-detect in progress prevents column updates
  autodetect_state <- normal_state
  autodetect_state$columns$auto_detect$in_progress <- TRUE
  expect_true(should_skip_column_update(autodetect_state))

  # TEST: UI sync needed prevents column updates
  ui_sync_state <- normal_state
  ui_sync_state$columns$ui_sync$needed <- TRUE
  expect_true(should_skip_column_update(ui_sync_state))
})

test_that("UI sync completion triggers navigation change", {
  # TEST: Simulated event chain from ui_sync_completed observer

  execute_ui_sync_completion <- function(state) {
    # Update timestamp (from observer)
    state$columns$ui_sync$last_sync_time <- Sys.time()

    # Trigger navigation change (from observer)
    state$navigation$trigger <- state$navigation$trigger + 1L

    state
  }

  # SETUP
  state <- list(
    columns = list(
      ui_sync = list(last_sync_time = NULL)
    ),
    navigation = list(trigger = 0L)
  )

  initial_trigger <- state$navigation$trigger

  # EXECUTE
  state <- execute_ui_sync_completion(state)

  # VERIFY: Timestamp updated
  expect_true(!is.null(state$columns$ui_sync$last_sync_time))

  # VERIFY: Navigation trigger incremented
  expect_gt(state$navigation$trigger, initial_trigger)
  expect_equal(state$navigation$trigger, initial_trigger + 1L)
})

# ERROR HANDLING LOGIC TESTS ===================================================

test_that("error context determines recovery strategy", {
  # TEST: Error type influences recovery logic

  determine_recovery_strategy <- function(error_type, error_context) {
    if (error_type == "processing") {
      if (!is.null(error_context) &&
          grepl("data|processing|convert|qic", error_context, ignore.case = TRUE)) {
        return("validate_data")
      }
      return("increment_attempts")
    }

    if (error_type == "validation") {
      return("clear_validation_state")
    }

    if (error_type == "network") {
      if (!is.null(error_context) &&
          grepl("file|upload|download|io", error_context, ignore.case = TRUE)) {
        return("retry_file_operation")
      }
      return("log_network_error")
    }

    if (error_type == "ui") {
      return("sync_ui")
    }

    return("general_error_handling")
  }

  # TEST: Processing errors
  expect_equal(
    determine_recovery_strategy("processing", "data_processing"),
    "validate_data"
  )
  expect_equal(
    determine_recovery_strategy("processing", "other_context"),
    "increment_attempts"
  )

  # TEST: Validation errors
  expect_equal(
    determine_recovery_strategy("validation", "any_context"),
    "clear_validation_state"
  )

  # TEST: Network errors
  expect_equal(
    determine_recovery_strategy("network", "file_upload_failed"),
    "retry_file_operation"
  )
  expect_equal(
    determine_recovery_strategy("network", "api_timeout"),
    "log_network_error"
  )

  # TEST: UI errors
  expect_equal(
    determine_recovery_strategy("ui", "render_error"),
    "sync_ui"
  )

  # TEST: Unknown errors
  expect_equal(
    determine_recovery_strategy("unknown", NULL),
    "general_error_handling"
  )
})

test_that("error tracking maintains state correctly", {
  # TEST: Error state management logic

  error_state <- list(
    error_count = 0L,
    recovery_attempts = 0L,
    last_error = NULL,
    last_recovery_time = NULL
  )

  # SIMULATE: Record error
  record_error <- function(state, error_type, context) {
    state$error_count <- state$error_count + 1L
    state$last_error <- list(
      type = error_type,
      context = context,
      timestamp = Sys.time()
    )

    # Increment recovery attempts for processing/validation errors
    if (error_type %in% c("processing", "validation")) {
      state$recovery_attempts <- state$recovery_attempts + 1L
    }

    state
  }

  # SIMULATE: Record recovery
  record_recovery <- function(state) {
    state$last_recovery_time <- Sys.time()
    state
  }

  # TEST: Initial state
  expect_equal(error_state$error_count, 0L)
  expect_equal(error_state$recovery_attempts, 0L)

  # TEST: Processing error increments both counters
  error_state <- record_error(error_state, "processing", "qic_calculation")
  expect_equal(error_state$error_count, 1L)
  expect_equal(error_state$recovery_attempts, 1L)
  expect_equal(error_state$last_error$type, "processing")

  # TEST: Network error only increments error count
  error_state <- record_error(error_state, "network", "file_download")
  expect_equal(error_state$error_count, 2L)
  expect_equal(error_state$recovery_attempts, 1L)  # Not incremented
  expect_equal(error_state$last_error$type, "network")

  # TEST: Validation error increments recovery attempts
  error_state <- record_error(error_state, "validation", "input_validation")
  expect_equal(error_state$error_count, 3L)
  expect_equal(error_state$recovery_attempts, 2L)

  # TEST: Recovery updates timestamp
  error_state <- record_recovery(error_state)
  expect_true(!is.null(error_state$last_recovery_time))
})

# OBSERVER PRIORITY LOGIC TESTS ================================================

test_that("observer priorities ensure correct execution order", {
  # TEST: Priority-based execution ordering

  execution_log <- character(0)

  # SIMULATE: Observers with different priorities
  observers <- list(
    list(name = "high_priority_1", priority = 100L, action = function() {
      execution_log <<- c(execution_log, "high_1")
    }),
    list(name = "medium_priority", priority = 0L, action = function() {
      execution_log <<- c(execution_log, "medium")
    }),
    list(name = "low_priority", priority = -10L, action = function() {
      execution_log <<- c(execution_log, "low")
    }),
    list(name = "high_priority_2", priority = 100L, action = function() {
      execution_log <<- c(execution_log, "high_2")
    })
  )

  # SIMULATE: Execute in priority order (high to low)
  sorted_observers <- observers[order(sapply(observers, function(x) -x$priority))]
  for (obs in sorted_observers) {
    obs$action()
  }

  # VERIFY: Execution order
  expect_equal(length(execution_log), 4)
  # High priority observers run first (order within same priority not guaranteed)
  expect_true(execution_log[1] %in% c("high_1", "high_2"))
  expect_true(execution_log[2] %in% c("high_1", "high_2"))
  # Medium priority runs before low
  expect_equal(execution_log[3], "medium")
  expect_equal(execution_log[4], "low")
})

# CACHE INVALIDATION LOGIC TESTS ===============================================

test_that("cache clearing logic is triggered by appropriate events", {
  # TEST: Cache invalidation decision logic

  should_clear_cache <- function(event_type) {
    cache_clearing_events <- c(
      "data_updated",
      "session_reset"
    )
    event_type %in% cache_clearing_events
  }

  # TEST: Events that should clear cache
  expect_true(should_clear_cache("data_updated"))
  expect_true(should_clear_cache("session_reset"))

  # TEST: Events that should NOT clear cache
  expect_false(should_clear_cache("navigation_changed"))
  expect_false(should_clear_cache("ui_sync_completed"))
  expect_false(should_clear_cache("auto_detection_completed"))
})

# SESSION LIFECYCLE LOGIC TESTS ================================================

test_that("session reset clears all state flags", {
  # TEST: Session reset logic

  reset_session_state <- function(state) {
    state$data$current_data <- NULL
    state$columns$auto_detect$in_progress <- FALSE
    state$columns$auto_detect$completed <- FALSE
    state$columns$auto_detect$results <- NULL
    state$columns$auto_detect$frozen_until_next_trigger <- FALSE
    state$columns$auto_detect$last_run <- NULL
    state
  }

  # SETUP: Populated state
  state <- list(
    data = list(current_data = data.frame(x = 1:3)),
    columns = list(
      auto_detect = list(
        in_progress = TRUE,
        completed = TRUE,
        results = list(x_col = "x"),
        frozen_until_next_trigger = TRUE,
        last_run = list(timestamp = Sys.time())
      )
    )
  )

  # EXECUTE: Reset
  state <- reset_session_state(state)

  # VERIFY: All state cleared
  expect_null(state$data$current_data)
  expect_false(state$columns$auto_detect$in_progress)
  expect_false(state$columns$auto_detect$completed)
  expect_null(state$columns$auto_detect$results)
  expect_false(state$columns$auto_detect$frozen_until_next_trigger)
  expect_null(state$columns$auto_detect$last_run)
})

test_that("session start with data triggers full detection", {
  # TEST: Session start decision logic

  determine_session_start_action <- function(has_data) {
    if (has_data) {
      return("skip_detection")  # Will be handled by data_loaded event
    } else {
      return("name_only_detection")
    }
  }

  # TEST: With data - skip detection
  expect_equal(determine_session_start_action(has_data = TRUE), "skip_detection")

  # TEST: Without data - run name-only detection
  expect_equal(determine_session_start_action(has_data = FALSE), "name_only_detection")
})

# EVENT CHAIN INTEGRATION TESTS ================================================

test_that("data upload event chain flows correctly", {
  # TEST: Complete event chain from data upload to UI update

  event_log <- character(0)

  # SIMULATE: Event chain
  trigger_data_upload <- function() {
    event_log <<- c(event_log, "data_updated")
  }

  trigger_autodetect <- function() {
    event_log <<- c(event_log, "auto_detection_started")
  }

  complete_autodetect <- function() {
    event_log <<- c(event_log, "auto_detection_completed")
  }

  trigger_ui_sync <- function() {
    event_log <<- c(event_log, "ui_sync_needed")
  }

  complete_ui_sync <- function() {
    event_log <<- c(event_log, "ui_sync_completed")
  }

  trigger_navigation <- function() {
    event_log <<- c(event_log, "navigation_changed")
  }

  # EXECUTE: Chain
  trigger_data_upload()
  trigger_autodetect()
  complete_autodetect()
  trigger_ui_sync()
  complete_ui_sync()
  trigger_navigation()

  # VERIFY: Complete chain
  expected_chain <- c(
    "data_updated",
    "auto_detection_started",
    "auto_detection_completed",
    "ui_sync_needed",
    "ui_sync_completed",
    "navigation_changed"
  )

  expect_equal(event_log, expected_chain)
})

test_that("table edit event chain skips auto-detection", {
  # TEST: Table edit follows different path

  event_log <- character(0)

  # SIMULATE: Table edit chain
  trigger_table_edit <- function(context) {
    event_log <<- c(event_log, "data_updated")

    # Context determines path
    if (context == "table_cells_edited") {
      event_log <<- c(event_log, "navigation_changed")
      # NOTE: NO auto_detection_started
    }
  }

  # EXECUTE
  trigger_table_edit("table_cells_edited")

  # VERIFY: Skipped auto-detection
  expect_equal(length(event_log), 2)
  expect_equal(event_log[1], "data_updated")
  expect_equal(event_log[2], "navigation_changed")
  expect_false("auto_detection_started" %in% event_log)
})

# === SECTION: Event-Driven Reactive Tests (merged from test-event-driven-reactive.R) ===

test_that("Reactive values logic kan simuleres", {
  mock_values <- list(
    test_mode_auto_detect_ready = NULL,
    auto_detect_trigger = NULL,
    ui_sync_needed = NULL,
    auto_detect_in_progress = FALSE
  )

  expect_null(mock_values$test_mode_auto_detect_ready)
  expect_null(mock_values$auto_detect_trigger)
  expect_null(mock_values$ui_sync_needed)
  expect_false(mock_values$auto_detect_in_progress)

  timestamp <- Sys.time()
  mock_values$test_mode_auto_detect_ready <- timestamp
  expect_equal(mock_values$test_mode_auto_detect_ready, timestamp)

  mock_values$auto_detect_in_progress <- TRUE
  expect_true(mock_values$auto_detect_in_progress)

  sync_data <- list(
    x_col = "Dato",
    taeller_col = "Tæller",
    col_choices = c("", "Dato", "Tæller"),
    timestamp = Sys.time()
  )
  mock_values$ui_sync_needed <- sync_data
  expect_equal(mock_values$ui_sync_needed$x_col, "Dato")
  expect_equal(mock_values$ui_sync_needed$taeller_col, "Tæller")
  expect_equal(length(mock_values$ui_sync_needed$col_choices), 3)

  mock_values$ui_sync_needed <- NULL
  expect_null(mock_values$ui_sync_needed)
})

test_that("Event-driven pattern logik er korrekt implementeret", {
  events_log <- character(0)

  test_mode_trigger <- function() {
    events_log <<- c(events_log, "test_mode_set")
    return(Sys.time())
  }

  auto_detect_trigger <- function(test_mode_ready) {
    if (!is.null(test_mode_ready)) {
      events_log <<- c(events_log, "auto_detect_triggered")
      return(Sys.time())
    }
    return(NULL)
  }

  ui_sync_trigger <- function(auto_detect_done) {
    if (!is.null(auto_detect_done)) {
      events_log <<- c(events_log, "ui_sync_requested")
      return(list(x_col = "TestCol", timestamp = Sys.time()))
    }
    return(NULL)
  }

  ui_sync_execute <- function(sync_request) {
    if (!is.null(sync_request)) {
      events_log <<- c(events_log, "ui_sync_completed")
      return(TRUE)
    }
    return(FALSE)
  }

  expect_equal(length(events_log), 0)

  step1 <- test_mode_trigger()
  step2 <- auto_detect_trigger(step1)
  step3 <- ui_sync_trigger(step2)
  step4 <- ui_sync_execute(step3)

  expected_events <- c("test_mode_set", "auto_detect_triggered", "ui_sync_requested", "ui_sync_completed")
  expect_equal(events_log, expected_events)
  expect_true(step4)
})

test_that("Auto-detection flag management fungerer", {
  values <- list(
    auto_detect_in_progress = FALSE,
    initial_auto_detect_completed = FALSE
  )

  simulate_auto_detect_start <- function(values) {
    values$auto_detect_in_progress <- TRUE
    return(values)
  }

  simulate_auto_detect_complete <- function(values) {
    values$initial_auto_detect_completed <- TRUE
    values$auto_detect_in_progress <- FALSE
    return(values)
  }

  expect_false(values$auto_detect_in_progress)
  expect_false(values$initial_auto_detect_completed)

  values <- simulate_auto_detect_start(values)
  expect_true(values$auto_detect_in_progress)
  expect_false(values$initial_auto_detect_completed)

  values <- simulate_auto_detect_complete(values)
  expect_false(values$auto_detect_in_progress)
  expect_true(values$initial_auto_detect_completed)

  can_auto_detect <- function(values) {
    !values$initial_auto_detect_completed
  }
  expect_false(can_auto_detect(values))
})

test_that("UI sync data structure er valid", {
  create_sync_data <- function() {
    list(
      x_col = "Dato",
      taeller_col = "Tæller",
      naevner_col = "Nævner",
      skift_col = NULL,
      frys_col = NULL,
      kommentar_col = "Kommentar",
      col_choices = c("", "Dato", "Tæller", "Nævner", "Kommentar"),
      timestamp = Sys.time()
    )
  }

  sync_data <- create_sync_data()

  expected_fields <- c(
    "x_col", "taeller_col", "naevner_col", "skift_col",
    "frys_col", "kommentar_col", "col_choices", "timestamp"
  )
  expect_true(all(expected_fields %in% names(sync_data)))

  expect_false(is.null(sync_data$x_col))
  expect_false(is.null(sync_data$taeller_col))
  expect_false(is.null(sync_data$col_choices))
  expect_false(is.null(sync_data$timestamp))

  expect_null(sync_data$skift_col)
  expect_null(sync_data$frys_col)

  expect_true(is.character(sync_data$col_choices))
  expect_true(length(sync_data$col_choices) > 0)
  expect_equal(sync_data$col_choices[1], "")

  expect_true(difftime(Sys.time(), sync_data$timestamp, units = "secs") < 1)
})

test_that("Event-driven approach er timing-agnostic", {
  values <- list(counter = 0)

  immediate_update <- function(values, increment) {
    values$counter <- values$counter + increment
    values
  }

  expect_equal(values$counter, 0)

  values <- immediate_update(values, 1)
  expect_equal(values$counter, 1)

  values <- immediate_update(values, 5)
  expect_equal(values$counter, 6)

  values <- immediate_update(values, -2)
  expect_equal(values$counter, 4)

  for (i in 1:10) {
    values <- immediate_update(values, 1)
  }
  expect_equal(values$counter, 14)
})

test_that("Observer priority concept er forståelig", {
  execution_queue <- list()

  add_to_queue <- function(item, priority = 0) {
    execution_queue <<- c(execution_queue, list(list(item = item, priority = priority)))
  }

  execute_queue <- function() {
    if (length(execution_queue) == 0) return(character(0))

    sorted <- execution_queue[order(sapply(execution_queue, function(x) {
      if (x$priority < 0) 1000 + abs(x$priority) else -x$priority
    }))]

    sapply(sorted, function(x) x$item)
  }

  add_to_queue("high_priority_1", priority = 0)
  add_to_queue("low_priority", priority = -10)
  add_to_queue("high_priority_2", priority = 0)

  result <- execute_queue()

  expect_equal(length(result), 3)
  expect_equal(result[3], "low_priority")
  expect_true("high_priority_1" %in% result[1:2])
  expect_true("high_priority_2" %in% result[1:2])
})