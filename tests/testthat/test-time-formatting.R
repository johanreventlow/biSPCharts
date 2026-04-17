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

test_that("time_breaks vaelger paene intervaller for typiske ranges", {
  # Range 0-120 min -> 30m interval -> 5 ticks
  breaks <- time_breaks(c(0, 120))
  expect_equal(breaks, c(0, 30, 60, 90, 120))

  # Range 15-185 min -> 30m interval (floor-snap begge ender)
  breaks <- time_breaks(c(15, 185))
  expect_equal(breaks, c(0, 30, 60, 90, 120, 150, 180))

  # Range 0-480 min (0-8t) -> 2t interval
  breaks <- time_breaks(c(0, 480))
  expect_equal(breaks, c(0, 120, 240, 360, 480))

  # Range 0-7200 min (0-5d) -> 1d interval
  breaks <- time_breaks(c(0, 7200))
  expect_equal(breaks, c(0, 1440, 2880, 4320, 5760, 7200))
})

test_that("time_breaks respekterer target_n argument", {
  # target_n = 3 giver grovere intervaller
  breaks <- time_breaks(c(0, 120), target_n = 3L)
  # Stoerste interval med >= 3 ticks for range 120: interval=60 (3 ticks)
  expect_equal(breaks, c(0, 60, 120))
})

test_that("time_breaks haandterer konstante og tomme inputs", {
  # Konstant range (min == max): returnér enkelt vaerdi
  breaks <- time_breaks(c(60, 60))
  expect_equal(breaks, 60)

  # NA input -> numeric(0)
  breaks_na <- time_breaks(c(NA_real_, NA_real_))
  expect_equal(breaks_na, numeric(0))

  # Tom input
  expect_equal(time_breaks(numeric(0)), numeric(0))
})

test_that("time_breaks snapper til interval-grid", {
  # Input range 45-155 -> snap til 30m-grid. Floor-snap paa begge ender giver
  # 30-150. Ggplot2's expansion() daekker y_max synligt over sidste tick.
  breaks <- time_breaks(c(45, 155))
  expect_true(all(breaks %% 30 == 0))
  expect_true(min(breaks) <= 45)
  expect_true(max(breaks) >= 150)
  # Sidste tick skal vaere indenfor én interval-afstand af y_max
  expect_true(max(breaks) >= 155 - 30)
})
