# test-parse-danish-number-thousand-sep.R
# Cycle D M1 (Codex 2026-05-10): regression-tests for conditional
# thousand-separator strip i parse_danish_number().
#
# Pre-fix: gsub(',', '.', x) uden grouping-strip -> '1.234,56' blev
# '1.234.56' -> as.numeric NA. Hospital-data fra Excel kunne silent
# bortfalde tællere/nævnere over 1000.
#
# Codex feedback: naiv "(?<=\\d)\\.(?=\\d{3}(\\D|$))"-regex ville turn
# '1.234' (engelsk point-decimal) til '1234' -> silent corruption.
#
# Post-fix: kun strip grouping-dots HVIS komma er til stede (entydigt
# dansk format-signal).

test_that("parse_danish_number haandterer dansk grouping + decimal", {
  require_internal("parse_danish_number", mode = "function")
  expect_equal(parse_danish_number("1.234,56"), 1234.56)
})

test_that("parse_danish_number bevarer engelsk point-decimal (NO corruption)", {
  require_internal("parse_danish_number", mode = "function")
  # KRITISK: tidligere naive regex ville turne 1.234 til 1234
  expect_equal(parse_danish_number("1.234"), 1.234)
  expect_equal(parse_danish_number("12.5"), 12.5)
})

test_that("parse_danish_number haandterer dansk decimal uden grouping", {
  require_internal("parse_danish_number", mode = "function")
  expect_equal(parse_danish_number("12,5"), 12.5)
  expect_equal(parse_danish_number("0,73"), 0.73)
})

test_that("parse_danish_number haandterer multi-grouping + decimal", {
  require_internal("parse_danish_number", mode = "function")
  expect_equal(parse_danish_number("1.234.567,89"), 1234567.89)
})

test_that("parse_danish_number fail-loudly paa malformed multiple commas", {
  require_internal("parse_danish_number", mode = "function")
  # '1,234,567' = ej valid format (kunne være amerikansk grouping eller
  # mistake) -> NA
  expect_true(is.na(parse_danish_number("1,234,567")))
})

test_that("parse_danish_number bevarer integer uden decimaler", {
  require_internal("parse_danish_number", mode = "function")
  expect_equal(parse_danish_number("100"), 100)
  expect_equal(parse_danish_number("1234"), 1234)
})

test_that("parse_danish_number haandterer NA + tom string", {
  require_internal("parse_danish_number", mode = "function")
  expect_true(is.na(parse_danish_number(NA_character_)))
  expect_true(is.na(parse_danish_number("")))
})

test_that("parse_danish_number body indeholder conditional strip-logic", {
  require_internal("parse_danish_number", mode = "function")
  body_text <- paste(deparse(body(parse_danish_number)), collapse = "\n")
  expect_true(
    grepl("grepl\\([^)]*[\"',][\"']", body_text) ||
      grepl("grepl\\([\"'],[\"']", body_text),
    info = "parse_danish_number skal kun strip grouping HVIS komma er til stede"
  )
})

test_that("parse_danish_number vector-input fungerer korrekt", {
  require_internal("parse_danish_number", mode = "function")
  result <- parse_danish_number(c("1.234,56", "1.234", "12,5", "12.5"))
  expect_equal(result[1], 1234.56)
  expect_equal(result[2], 1.234)
  expect_equal(result[3], 12.5)
  expect_equal(result[4], 12.5)
})
