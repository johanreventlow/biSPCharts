# test-local-storage-time-migration.R
# Tests for silent forward-migration af y_axis_unit fra schema 2.0 til 3.0.
# Se docs/superpowers/specs/2026-04-17-time-yaxis-design.md for rationale.

library(testthat)

test_that("migrate_time_yaxis_unit konverterer legacy 'time' til 'time_minutes'", {
  saved_state <- list(
    version = "2.0",
    metadata = list(
      y_axis_unit = "time",
      chart_type = "t",
      title = "Test"
    )
  )
  migrated <- migrate_time_yaxis_unit(saved_state)
  expect_equal(migrated$metadata$y_axis_unit, "time_minutes")
  expect_equal(migrated$version, "3.0")
})

test_that("migrate_time_yaxis_unit lader ikke-time enheder vaere i fred", {
  saved_state <- list(
    version = "2.0",
    metadata = list(y_axis_unit = "count", chart_type = "p")
  )
  migrated <- migrate_time_yaxis_unit(saved_state)
  expect_equal(migrated$metadata$y_axis_unit, "count")
  expect_equal(migrated$version, "3.0")
})

test_that("migrate_time_yaxis_unit er idempotent for 3.0 payloads", {
  saved_state <- list(
    version = "3.0",
    metadata = list(y_axis_unit = "time_hours")
  )
  migrated <- migrate_time_yaxis_unit(saved_state)
  expect_equal(migrated$metadata$y_axis_unit, "time_hours")
  expect_equal(migrated$version, "3.0")
})

test_that("migrate_time_yaxis_unit haandterer manglende metadata graciously", {
  saved_state <- list(version = "2.0", data = list(nrows = 10))
  migrated <- migrate_time_yaxis_unit(saved_state)
  expect_equal(migrated$version, "3.0")
})

test_that("migrate_time_yaxis_unit returnerer NULL for NULL input", {
  expect_null(migrate_time_yaxis_unit(NULL))
})

test_that("migrate_time_yaxis_unit lader ukendt version vaere i fred", {
  saved_state <- list(
    version = "1.5",
    metadata = list(y_axis_unit = "time")
  )
  migrated <- migrate_time_yaxis_unit(saved_state)
  expect_equal(migrated$version, "1.5")
  expect_equal(migrated$metadata$y_axis_unit, "time")
})
