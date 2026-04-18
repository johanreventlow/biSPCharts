# test-time-parsing.R
# Tests for parse_time_to_minutes() — konverterer diverse tids-inputs
# til kanoniske minutter.

library(testthat)

test_that("parse_time_to_minutes haandterer numerisk input med input_unit", {
  expect_equal(parse_time_to_minutes(90, "time_minutes"), 90)
  expect_equal(parse_time_to_minutes(1.5, "time_hours"), 90)
  expect_equal(parse_time_to_minutes(0.0625, "time_days"), 90)
})

test_that("parse_time_to_minutes er vektoriseret", {
  input <- c(30, 60, 90, 120)
  expect_equal(parse_time_to_minutes(input, "time_minutes"), c(30, 60, 90, 120))
  expect_equal(parse_time_to_minutes(c(1, 2, 3), "time_hours"), c(60, 120, 180))
  expect_equal(parse_time_to_minutes(c(1, 2), "time_days"), c(1440, 2880))
})

test_that("parse_time_to_minutes haandterer NA", {
  expect_true(is.na(parse_time_to_minutes(NA_real_, "time_minutes")))
  expect_equal(
    parse_time_to_minutes(c(1, NA, 2), "time_hours"),
    c(60, NA_real_, 120)
  )
})

test_that("parse_time_to_minutes defaulter til time_minutes for ugyldig input_unit", {
  suppressWarnings({
    expect_equal(parse_time_to_minutes(90, NULL), 90)
    expect_equal(parse_time_to_minutes(90, "bogus_unit"), 90)
  })
})
