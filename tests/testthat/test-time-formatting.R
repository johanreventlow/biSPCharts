# test-time-formatting.R
# Tests for tids-kompositformat og tids-naturlige tick-breaks.
# Implementerer Fase 1 af docs/superpowers/specs/2026-04-17-time-yaxis-design.md

library(testthat)

test_that("format_time_composite haandterer grundlaeggende minutter", {
  expect_equal(format_time_composite(0), "0m")
  expect_equal(format_time_composite(1), "1m")
  expect_equal(format_time_composite(45), "45m")
  expect_equal(format_time_composite(59), "59m")
})

test_that("format_time_composite haandterer timer og timer+minutter", {
  expect_equal(format_time_composite(60), "1t")
  expect_equal(format_time_composite(90), "1t 30m")
  expect_equal(format_time_composite(120), "2t")
  expect_equal(format_time_composite(125), "2t 5m")
  expect_equal(format_time_composite(1439), "23t 59m")
})

test_that("format_time_composite haandterer dage", {
  # Ved dage ignoreres minutter (max 2 komponenter: dage+timer)
  expect_equal(format_time_composite(1440), "1d")
  expect_equal(format_time_composite(1500), "1d 1t")
  expect_equal(format_time_composite(2880), "2d")
  expect_equal(format_time_composite(3660), "2d 13t")
})
