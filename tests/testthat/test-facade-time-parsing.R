# test-facade-time-parsing.R
# Integrationstests for tids-parsing i fct_spc_bfh_facade.R.
# Verificerer at parse_time_to_minutes() kaldes korrekt når y_axis_unit er
# en tids-enhed, og at time_* enheder mappes til "time" for BFHcharts.

library(testthat)

test_that("parse_time_to_minutes skalerer hours -> kanoniske minutter", {
  # Regression test: hvis en bruger har y-data i timer og vaelger
  # time_hours som enhed, skal vaerdierne ganges med 60 foer de sendes
  # til BFHcharts' SPC-beregning.
  y_hours <- c(1, 1.5, 2, 2.5)
  parsed <- parse_time_to_minutes(y_hours, input_unit = "time_hours")
  expect_equal(parsed, c(60, 90, 120, 150))
})

test_that("parse_time_to_minutes skalerer days -> minutter", {
  y_days <- c(1, 2, 7)
  parsed <- parse_time_to_minutes(y_days, input_unit = "time_days")
  expect_equal(parsed, c(1440, 2880, 10080))
})

test_that("parse_time_to_minutes haandterer HH:MM-strenge i facade-kontekst", {
  # CSV-import giver karakter-kolonner; facade skal kunne haandtere dette.
  y_strings <- c("00:30", "01:00", "01:30", "02:15")
  parsed <- parse_time_to_minutes(y_strings, input_unit = "time_minutes")
  expect_equal(parsed, c(30, 60, 90, 135))
})

test_that("is_time_unit identificerer korrekt for BFHcharts-mapping", {
  # Facaden bruger is_time_unit() til at beslutte om y_axis_unit skal
  # mappes til "time" foer det sendes til BFHcharts.
  expect_true(is_time_unit("time_minutes"))
  expect_true(is_time_unit("time_hours"))
  expect_true(is_time_unit("time_days"))
  expect_true(is_time_unit("time"))  # legacy
  expect_false(is_time_unit("count"))
})

test_that("parse_time_to_minutes skalerer target og centerline-vaerdier", {
  # Bruger saetter target = 90 med y-enhed "time_days": target skal tolkes
  # som 90 dage (= 129600 min), ikke 90 minutter.
  expect_equal(parse_time_to_minutes(90, input_unit = "time_days"), 129600)

  # Target = 5 timer skal tolkes som 300 min
  expect_equal(parse_time_to_minutes(5, input_unit = "time_hours"), 300)

  # Target = 60 minutter er 60 min
  expect_equal(parse_time_to_minutes(60, input_unit = "time_minutes"), 60)

  # NULL target returnerer numeric(0) — caller skal haandtere
  expect_equal(parse_time_to_minutes(numeric(0), "time_days"), numeric(0))
})
