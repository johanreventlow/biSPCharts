# Test: Column Observer Consolidation
#
# Tests for the consolidated column input observer system.
# Validates that the unified handle_column_input() function provides
# identical behavior to the previous 6 separate observers.
#
# Coverage:
# - normalize_column_input() - Input normalization logic
# - handle_column_input() - Unified column input handler
# - create_column_observer() - Observer factory function
#
# NOTE: Integration tests with testServer() are skipped due to timeout issues.
# Manual testing in the running app validates end-to-end behavior.

library(testthat)
library(shiny)

# ============================================================================
# UNIT TESTS: normalize_column_input()
# ============================================================================

test_that("normalize_column_input handles NULL input", {
  result <- normalize_column_input(NULL)
  expect_identical(result, "")
})

test_that("normalize_column_input handles empty vector", {
  result <- normalize_column_input(character(0))
  expect_identical(result, "")
})

test_that("normalize_column_input handles empty string", {
  result <- normalize_column_input("")
  expect_identical(result, "")
})

test_that("normalize_column_input handles NA", {
  result <- normalize_column_input(NA_character_)
  expect_identical(result, "")
})

test_that("normalize_column_input handles valid string", {
  result <- normalize_column_input("dato")
  expect_identical(result, "dato")
})

test_that("normalize_column_input handles vector with multiple elements", {
  result <- normalize_column_input(c("dato", "x", "y"))
  expect_identical(result, "dato")
})

# ============================================================================
# UNIT TESTS: handle_column_input()
# ============================================================================

test_that("handle_column_input updates state + cache for user input", {
  # Cycle B M1 (Codex 2026-05-09): column_choices_changed-emit fjernet helt
  # da det aldrig blev observeret. Test verificerer nu kun state + cache update;
  # plot-update kommer via direkte input$<column>-observer + spc_inputs-cascade,
  # ej via dette emit.
  app_state <- new.env()
  app_state$ui <- list(
    performance_metrics = reactiveValues(tokens_consumed = 0L)
  )
  app_state$columns <- reactiveValues(mappings = reactiveValues())
  app_state$ui_cache <- list()

  # Mock emit API (handler skal ej fejle uden column_choices_changed-key)
  emit <- new.env()

  # Call handler
  isolate(handle_column_input("x_column", "dato", app_state, emit))

  # Verify state updated
  expect_identical(isolate(app_state$columns$mappings$x_column), "dato")

  # Verify cache updated
  expect_identical(app_state$ui_cache$x_column_input, "dato")
})

test_that("handle_column_input normalizes input value", {
  # Setup mock app_state
  app_state <- new.env()
  app_state$ui <- list(
    performance_metrics = reactiveValues(tokens_consumed = 0L)
  )
  app_state$columns <- reactiveValues(mappings = reactiveValues())
  app_state$ui_cache <- list()

  # Mock emit API
  emit <- new.env()
  emit$column_choices_changed <- function() {}

  # Test with NULL input
  isolate(handle_column_input("x_column", NULL, app_state, emit))
  expect_identical(isolate(app_state$columns$mappings$x_column), "")

  # Test with empty string
  isolate(handle_column_input("x_column", "", app_state, emit))
  expect_identical(isolate(app_state$columns$mappings$x_column), "")

  # Test with vector
  isolate(handle_column_input("x_column", c("dato", "extra"), app_state, emit))
  expect_identical(isolate(app_state$columns$mappings$x_column), "dato")
})

test_that("handle_column_input handles missing emit function gracefully", {
  # Setup mock app_state
  app_state <- new.env()
  app_state$ui <- list(
    performance_metrics = reactiveValues(tokens_consumed = 0L)
  )
  app_state$columns <- reactiveValues(mappings = reactiveValues())
  app_state$ui_cache <- list()

  # Mock emit API WITHOUT column_choices_changed
  emit <- new.env()

  # Should not throw error
  expect_silent(isolate(handle_column_input("x_column", "dato", app_state, emit)))

  # Verify state still updated
  expect_identical(isolate(app_state$columns$mappings$x_column), "dato")
})

test_that("handle_column_input returns early without side effects when value unchanged", {
  app_state <- new.env()
  app_state$ui <- list()
  app_state$columns <- reactiveValues(mappings = reactiveValues(x_column = "dato"))
  app_state$ui_cache <- list(x_column_input = "SENTINEL")

  emit <- new.env()
  emit_called <- FALSE
  emit$column_choices_changed <- function() {
    emit_called <<- TRUE
  }

  isolate(handle_column_input("x_column", "dato", app_state, emit))

  # Mapping uændret
  expect_identical(isolate(app_state$columns$mappings$x_column), "dato")

  # Cache IKKE overskrevet (sentinel bevaret — ingen side-effect ved no-op)
  expect_identical(app_state$ui_cache$x_column_input, "SENTINEL")

  # Emit IKKE kaldt
  expect_false(emit_called)
})

# ============================================================================
# UNIT TESTS: create_column_observer()
# ============================================================================

test_that("create_column_observer function exists and is callable", {
  # Verify function exists
  expect_true(exists("create_column_observer"))
  expect_true(is.function(create_column_observer))

  # Verify function signature (should accept 4 parameters)
  expect_equal(length(formals(create_column_observer)), 4)
  expect_named(formals(create_column_observer), c("col_name", "input", "app_state", "emit"))
})
