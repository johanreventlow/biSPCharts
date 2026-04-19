# Tests for Reactive Batching Utilities
# Testing batching behavior to prevent reactive storms

library(testthat)
library(shiny)

# Simplified test without later event loop dependency
test_that("schedule_batched_update schedules execution", {
  skip_if_not(requireNamespace("later", quietly = TRUE), "later package not available")

  executed <- FALSE

  # This schedules but doesn't execute in test context (later event loop)
  expect_silent({
    schedule_batched_update(
      update_fn = function() {
        executed <<- TRUE
      },
      delay_ms = 10
    )
  })

  # Should not execute immediately (verified by silent scheduling)
  expect_false(executed)
})

# 5 test-blokke fjernet i §1.2.2 (PR-batch A+B):
# is_batch_pending() og clear_all_batches() state-inspection-helpers blev
# aldrig implementeret i R/. Kun schedule_batched_update() eksisterer
# (R/utils_reactive_batching.R:74). Tests forudsatte en state-tracking-
# arkitektur der ikke findes. Se docs/test-suite-inventory-203.md §
# "Inventory af skip('TODO')-kald".

test_that("schedule_batched_update validates input parameters", {
  expect_error(
    schedule_batched_update(update_fn = "not a function", delay_ms = 50),
    "update_fn must be a function"
  )

  expect_error(
    schedule_batched_update(update_fn = function() {}, delay_ms = -10),
    "delay_ms must be a non-negative number"
  )

  expect_error(
    schedule_batched_update(update_fn = function() {}, delay_ms = "invalid"),
    "delay_ms must be a non-negative number"
  )
})

# Integrationstest "handle_column_input uses batching infrastructure"
# fjernet i §1.2.2 — afhængig af is_batch_pending/clear_all_batches (ikke
# implementeret). Se note ovenfor.

# Edge case: Fallback behavior without app_state
test_that("schedule_batched_update works without app_state (fallback mode)", {
  skip_if_not(requireNamespace("later", quietly = TRUE), "later package not available")

  # Should work without app_state (no batching tracking)
  expect_silent({
    schedule_batched_update(
      update_fn = function() {},
      delay_ms = 10,
      app_state = NULL
    )
  })

  # No app_state means no batching tracking (just scheduling)
  # This tests the fallback path works without errors
})

# Test "batching infrastructure is created lazily" fjernet i §1.2.2 —
# forudsat app_state$batching-environment eksisterer ikke i nuværende
# reactive batching implementation. Se note ovenfor.
