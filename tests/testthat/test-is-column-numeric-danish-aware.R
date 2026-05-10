# test-is-column-numeric-danish-aware.R
# Cycle D H1 (Codex 2026-05-10): regression-tests for danish-aware
# is_column_numeric().
#
# Pre-fix: is_column_numeric() brugte as.numeric(as.character()) der ikke
# haandterer komma som decimal-separator. Karakter-kolonner med danske tal
# ("12,5", "0,73") returnerede success-rate 0 -> falsk Y-axis-fejl efter
# localStorage-roundtrip eller Excel-til-text-konvertering.
#
# Post-fix: parse_danish_number() bruges -> accepterer baade "12,5" og "12.5".

test_that("is_column_numeric accepterer danske komma-decimaler", {
  require_internal("is_column_numeric", mode = "function")
  expect_true(is_column_numeric(c("12,5", "0,73", "3,14")))
})

test_that("is_column_numeric accepterer engelske punktum-decimaler", {
  require_internal("is_column_numeric", mode = "function")
  expect_true(is_column_numeric(c("12.5", "0.73", "3.14")))
})

test_that("is_column_numeric afviser ren tekst", {
  require_internal("is_column_numeric", mode = "function")
  expect_false(is_column_numeric(c("foo", "bar", "baz")))
})

test_that("is_column_numeric accepterer mixed valid+text over threshold", {
  require_internal("is_column_numeric", mode = "function")
  # 50% numeric (default threshold) -> TRUE
  expect_true(is_column_numeric(c("12,5", "foo")))
})

test_that("is_column_numeric afviser mixed under threshold", {
  require_internal("is_column_numeric", mode = "function")
  # 25% numeric (under default 50%) -> FALSE
  expect_false(is_column_numeric(c("12,5", "foo", "bar", "baz")))
})

test_that("is_column_numeric haandterer numeric vector direkte", {
  require_internal("is_column_numeric", mode = "function")
  expect_true(is_column_numeric(c(1.5, 2.5, 3.5)))
})

test_that("is_column_numeric haandterer all-NA gracefully", {
  require_internal("is_column_numeric", mode = "function")
  expect_true(is_column_numeric(NA))
  expect_true(is_column_numeric(c(NA, NA, NA)))
})

test_that("is_column_numeric haandterer integer vector", {
  require_internal("is_column_numeric", mode = "function")
  expect_true(is_column_numeric(1:10))
})

test_that("is_column_numeric body bruger parse_danish_number", {
  require_internal("is_column_numeric", mode = "function")
  body_text <- paste(deparse(body(is_column_numeric)), collapse = "\n")
  expect_true(
    grepl("parse_danish_number", body_text),
    info = "is_column_numeric skal bruge parse_danish_number for danish-aware parsing"
  )
})
