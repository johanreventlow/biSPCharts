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

test_that("parse_time_to_minutes haandterer difftime med forskellige enheder", {
  # difftime i minutter — input_unit ignoreres for difftime
  dt_min <- as.difftime(c(30, 60, 90), units = "mins")
  expect_equal(parse_time_to_minutes(dt_min, "time_hours"), c(30, 60, 90))

  # difftime i timer
  dt_hrs <- as.difftime(c(1, 2, 3), units = "hours")
  expect_equal(parse_time_to_minutes(dt_hrs, "time_minutes"), c(60, 120, 180))

  # difftime i sekunder (giver brøkdele af minutter)
  dt_sec <- as.difftime(c(60, 120, 90), units = "secs")
  expect_equal(parse_time_to_minutes(dt_sec), c(1, 2, 1.5))
})

test_that("parse_time_to_minutes haandterer hms objekter", {
  skip_if_not_installed("hms")
  h <- hms::hms(seconds = c(90 * 60, 30 * 60))  # 90 min og 30 min
  expect_equal(parse_time_to_minutes(h), c(90, 30))
})

test_that("parse_time_to_minutes haandterer HH:MM-strenge", {
  expect_equal(parse_time_to_minutes("01:30"), 90)
  expect_equal(parse_time_to_minutes("00:45"), 45)
  expect_equal(parse_time_to_minutes("02:00"), 120)
  # Værdier >24t er valide (kumulerede tider)
  expect_equal(parse_time_to_minutes("25:15"), 25 * 60 + 15)
  # Enkelt-cifre timer og minutter
  expect_equal(parse_time_to_minutes("1:5"), 65)
})

test_that("parse_time_to_minutes haandterer HH:MM:SS", {
  # Sekunder bevares som brøkdele af minutter
  expect_equal(parse_time_to_minutes("01:30:15"), 90.25)
  expect_equal(parse_time_to_minutes("01:30:45"), 90.75)
  expect_equal(parse_time_to_minutes("00:00:30"), 0.5)
})

test_that("parse_time_to_minutes haandterer ugyldige strenge som NA", {
  suppressWarnings({
    expect_true(is.na(parse_time_to_minutes("invalid")))
    expect_true(is.na(parse_time_to_minutes("abc:def")))
    expect_true(is.na(parse_time_to_minutes("")))
  })
})

test_that("parse_time_to_minutes haandterer blandet karakter-vektor", {
  suppressWarnings({
    result <- parse_time_to_minutes(c("01:30", "invalid", "00:45", NA))
    expect_equal(result, c(90, NA_real_, 45, NA_real_))
  })
})

test_that("parse_time_to_minutes kan stadig parse numeriske strenge", {
  # Strenge der ser ud som numre (ingen ':' til HH:MM-parse)
  # behandles som numeric med input_unit
  expect_equal(parse_time_to_minutes("90", "time_minutes"), 90)
  expect_equal(parse_time_to_minutes("1.5", "time_hours"), 90)
})
