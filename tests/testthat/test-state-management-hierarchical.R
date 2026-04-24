# test-state-management-hierarchical.R
# Comprehensive tests for hierarchical state management system
# Tests the new app_state architecture with reactive values and event systems
# Foundation for all other functionality - critical path testing

test_that("create_app_state basic functionality works", {
  # TEST: Core app_state creation and structure

  # Skip if create_app_state function not available
  skip_if_not(exists("create_app_state", mode = "function"), "create_app_state function not available")

  # SETUP: Create app state
  app_state <- create_app_state()

  # Verify basic structure
  expect_true(is.environment(app_state))
  expect_true("events" %in% names(app_state))
  expect_true("data" %in% names(app_state))
  expect_true("columns" %in% names(app_state))

  # Verify reactive values structure
  expect_s3_class(app_state$events, "reactivevalues")
  expect_s3_class(app_state$data, "reactivevalues")
  expect_s3_class(app_state$columns, "reactivevalues")

  # Verify hierarchical column structure (nested reactive values kræver isolate)
  expect_s3_class(isolate(app_state$columns$auto_detect), "reactivevalues")
  expect_s3_class(isolate(app_state$columns$mappings), "reactivevalues")
  expect_s3_class(isolate(app_state$columns$ui_sync), "reactivevalues")
})

test_that("app_state event system works correctly", {
  # TEST: Event bus functionality and triggering

  # SETUP: Create app state
  app_state <- create_app_state()

  # TEST: Initial event values
  # data_updated er det konsoliderede event (erstatter data_loaded, data_changed)
  expect_equal(isolate(app_state$events$data_updated), 0L)
  expect_equal(isolate(app_state$events$auto_detection_started), 0L)
  # ui_sync_requested er det aktuelle navn (erstatter ui_sync_needed)
  expect_equal(isolate(app_state$events$ui_sync_requested), 0L)

  # TEST: Event triggering
  app_state$events$data_updated <- isolate(app_state$events$data_updated) + 1L
  expect_equal(isolate(app_state$events$data_updated), 1L)

  # TEST: Multiple event types
  app_state$events$auto_detection_completed <- 1L
  app_state$events$ui_sync_requested <- 1L

  expect_equal(isolate(app_state$events$auto_detection_completed), 1L)
  expect_equal(isolate(app_state$events$ui_sync_requested), 1L)

  # TEST: Event independence
  expect_equal(isolate(app_state$events$data_updated), 1L) # Should remain unchanged
})

test_that("app_state data management works", {
  # TEST: Data management reactive values

  # SETUP: Create app state
  app_state <- create_app_state()

  # TEST: Initial data state
  expect_null(isolate(app_state$data$current_data))
  expect_null(isolate(app_state$data$original_data))
  expect_false(isolate(app_state$data$updating_table))
  expect_equal(isolate(app_state$data$table_version), 0)

  # TEST: Data assignment
  test_data <- data.frame(
    Dato = c("01-01-2024", "01-02-2024"),
    Værdi = c(45, 43),
    stringsAsFactors = FALSE
  )

  app_state$data$current_data <- test_data
  app_state$data$original_data <- test_data

  expect_equal(nrow(isolate(app_state$data$current_data)), 2)
  expect_equal(nrow(isolate(app_state$data$original_data)), 2)
  expect_true(all(names(isolate(app_state$data$current_data)) == c("Dato", "Værdi")))

  # TEST: Table operation flags
  app_state$data$updating_table <- TRUE
  app_state$data$table_version <- 1

  expect_true(isolate(app_state$data$updating_table))
  expect_equal(isolate(app_state$data$table_version), 1)

  # TEST: File metadata
  app_state$data$file_info <- list(name = "test.csv", size = 1024)
  app_state$data$file_path <- "/path/to/test.csv"

  expect_equal(isolate(app_state$data$file_info)$name, "test.csv")
  expect_equal(isolate(app_state$data$file_path), "/path/to/test.csv")
})

test_that("app_state environment-based sharing works", {
  # TEST: Environment-based by-reference sharing

  # SETUP: Create app state
  app_state <- create_app_state()

  # TEST: Function that modifies state by reference
  # (nested reactive values kræver isolate for at sætte)
  modify_state <- function(state) {
    state$data$current_data <- data.frame(test = "modified")
    m <- isolate(state$columns$mappings)
    m$x_column <- "modified_column"
    state$events$data_updated <- 99L
  }

  # Modify state through function
  modify_state(app_state)

  # Verify changes persist (environment passed by reference)
  expect_equal(isolate(app_state$data$current_data)$test, "modified")
  # columns$mappings er nested reactive - kræver isolate(isolate(...))
  m <- isolate(app_state$columns$mappings)
  expect_equal(isolate(m$x_column), "modified_column")
  expect_equal(isolate(app_state$events$data_updated), 99L)

  # TEST: Multiple references to same environment
  app_state_ref1 <- app_state
  app_state_ref2 <- app_state

  app_state_ref1$data$table_version <- 100

  # Both references should see the change
  expect_equal(isolate(app_state_ref2$data$table_version), 100)
  expect_equal(isolate(app_state$data$table_version), 100)
})

test_that("app_state session management works", {
  # TEST: Session-related state management

  # SETUP: Create app state with session components
  app_state <- create_app_state()

  # Verify session structure exists if defined
  if ("session" %in% names(app_state)) {
    # TEST: Session state initial values
    expect_true(isolate(app_state$session$auto_save_enabled) %||% TRUE)
    expect_false(isolate(app_state$session$restoring_session) %||% FALSE)
    expect_false(isolate(app_state$session$file_uploaded) %||% FALSE)

    # TEST: Session state updates
    app_state$session$file_uploaded <- TRUE
    app_state$session$user_started_session <- TRUE
    app_state$session$file_name <- "test_data.csv"

    expect_true(isolate(app_state$session$file_uploaded))
    expect_true(isolate(app_state$session$user_started_session))
    expect_equal(isolate(app_state$session$file_name), "test_data.csv")
  }
})

test_that("app_state error handling and recovery works", {
  # TEST: Error states and recovery mechanisms

  # SETUP: Create app state
  app_state <- create_app_state()

  # TEST: Error event handling
  # error_occurred er det konsoliderede event (validation_error og processing_error er ikke separate)
  expect_equal(isolate(app_state$events$error_occurred), 0L)

  # validation_error og processing_error er ikke egne events længere
  # de er konsolideret til error_occurred med context
  # Trigger the consolidated error event
  app_state$events$error_occurred <- 1L
  expect_equal(isolate(app_state$events$error_occurred), 1L)

  # TEST: Recovery workflow
  app_state$events$recovery_completed <- 1L
  expect_equal(isolate(app_state$events$recovery_completed), 1L)
})

test_that("app_state performance and memory management works", {
  set.seed(42)
  # TEST: Performance considerations and memory usage

  # SETUP: Create app state
  app_state <- create_app_state()

  # TEST: Large data handling
  large_data <- data.frame(
    x = 1:1000,
    y = sample(1:100, 1000, replace = TRUE),
    z = runif(1000)
  )

  # Measure memory impact
  start_time <- Sys.time()
  app_state$data$current_data <- large_data
  assignment_time <- as.numeric(Sys.time() - start_time)

  # Should handle large data efficiently
  expect_lt(assignment_time, 1.0) # Should complete in under 1 second
  expect_equal(nrow(isolate(app_state$data$current_data)), 1000)

  # TEST: State cleanup
  app_state$data$current_data <- NULL
  app_state$data$original_data <- NULL

  expect_null(isolate(app_state$data$current_data))
  expect_null(isolate(app_state$data$original_data))
})
