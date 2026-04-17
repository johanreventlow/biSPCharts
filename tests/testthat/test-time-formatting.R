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

test_that("format_time_composite runder overflow korrekt", {
  # 59,7 min rundet til 60 -> 1t (ikke 60m)
  expect_equal(format_time_composite(59.7), "1t")
  # 60,4 min rundet til 60 -> 1t
  expect_equal(format_time_composite(60.4), "1t")
  # 1439,7 min rundet til 1440 -> 1d
  expect_equal(format_time_composite(1439.7), "1d")
  # 119,5 min rundet til 120 -> 2t
  expect_equal(format_time_composite(119.5), "2t")
})

test_that("format_time_composite haandterer sub-minut vaerdier", {
  # 0,25 min -> rundes til 0 -> "0m"
  expect_equal(format_time_composite(0.25), "0m")
  # 0,6 min -> rundes til 1 -> "1m"
  expect_equal(format_time_composite(0.6), "1m")
})

test_that("format_time_composite haandterer negative vaerdier", {
  expect_equal(format_time_composite(-30), "-30m")
  expect_equal(format_time_composite(-90), "-1t 30m")
  expect_equal(format_time_composite(-1440), "-1d")
})

test_that("format_time_composite haandterer NA og tomme vektorer", {
  expect_true(is.na(format_time_composite(NA)))
  expect_true(is.na(format_time_composite(NA_real_)))
  expect_equal(format_time_composite(numeric(0)), character(0))
})

test_that("format_time_composite er vektoriseret", {
  input <- c(0, 60, 90, NA, 1440)
  expected <- c("0m", "1t", "1t 30m", NA_character_, "1d")
  expect_equal(format_time_composite(input), expected)
})

test_that("format_time_composite: regression test for 0,8541667 timer-bugget", {
  # 0,8541667 timer = 51,25 minutter. Forventet: "51m", ikke "0,8541667 timer"
  minutes_51 <- 0.8541667 * 60
  expect_equal(format_time_composite(minutes_51), "51m")
})
