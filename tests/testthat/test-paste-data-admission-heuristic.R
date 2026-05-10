# test-paste-data-admission-heuristic.R
# Cycle D H3 (Codex 2026-05-10): regression-tests for admission-specifik
# heuristik i handle_paste_data.
#
# Pre-fix: has_numeric <- any(is_column_numeric(threshold=0)) var DEAD CODE
# (0/N >= 0 = altid TRUE for ej-tom kolonne). Brugere kunne paste ren tekst
# -> validering tillader -> downstream crash.
#
# Codex feedback: threshold=0.5 (Y-axis-quality-heuristik) er for aggressivt
# for paste-admission. Sparse clinical-paste-data (1 numeric col + 4 char
# cols) kunne afvises trods valid measure-column.
#
# Post-fix: admission-specifik heuristik der kraever >=1 column med >=2
# parsed numeric values. Tillader sparse data, afviser ren tekst.

test_that("handle_paste_data afviser ren prose-tekst", {
  require_internal("handle_paste_data", mode = "function")
  body_text <- paste(deparse(body(handle_paste_data)), collapse = "\n")

  expect_true(
    grepl("count_parsed_numeric", body_text),
    info = "handle_paste_data skal bruge count_parsed_numeric admission-heuristik"
  )
  expect_true(
    grepl("numeric_counts\\s*>=\\s*2L", body_text),
    info = "Threshold skal vaere >= 2 for at undgaa single-value-noise"
  )
})

test_that("admission-heuristik logic afviser pure prose", {
  count_parsed_numeric <- function(col) {
    if (is.numeric(col)) {
      return(sum(!is.na(col)))
    }
    parsed <- parse_danish_number(as.character(col))
    sum(!is.na(parsed))
  }

  df <- data.frame(
    a = c("foo", "bar", "baz"),
    b = c("hello", "world", "test"),
    stringsAsFactors = FALSE
  )
  nc <- vapply(df, count_parsed_numeric, integer(1))
  expect_false(any(nc >= 2L))
})

test_that("admission-heuristik tillader normal numeric table", {
  count_parsed_numeric <- function(col) {
    if (is.numeric(col)) {
      return(sum(!is.na(col)))
    }
    parsed <- parse_danish_number(as.character(col))
    sum(!is.na(parsed))
  }

  df <- data.frame(
    date = c("2024-01-01", "2024-02-01"),
    value = c(95, 92),
    stringsAsFactors = FALSE
  )
  nc <- vapply(df, count_parsed_numeric, integer(1))
  expect_true(any(nc >= 2L))
})

test_that("admission-heuristik tillader sparse clinical-data (1/5 numeric col)", {
  count_parsed_numeric <- function(col) {
    if (is.numeric(col)) {
      return(sum(!is.na(col)))
    }
    parsed <- parse_danish_number(as.character(col))
    sum(!is.na(parsed))
  }

  df <- data.frame(
    dept = c("Kard", "Med", "Kir"),
    name = c("a", "b", "c"),
    code = c("x", "y", "z"),
    status = c("ok", "ok", "fail"),
    measurement = c("12,5", "13,2", "14,1"),
    stringsAsFactors = FALSE
  )
  nc <- vapply(df, count_parsed_numeric, integer(1))
  expect_true(any(nc >= 2L),
    info = "Sparse 1/5 numeric col skal admission-tillades (Codex's bekymring)"
  )
})

test_that("admission-heuristik afviser single-numeric-value (under threshold 2)", {
  count_parsed_numeric <- function(col) {
    if (is.numeric(col)) {
      return(sum(!is.na(col)))
    }
    parsed <- parse_danish_number(as.character(col))
    sum(!is.na(parsed))
  }

  df <- data.frame(
    a = c("foo", "bar"),
    b = c("12,5", "baz"), # kun 1 parsed numeric
    stringsAsFactors = FALSE
  )
  nc <- vapply(df, count_parsed_numeric, integer(1))
  expect_false(any(nc >= 2L),
    info = "Single numeric value skal afvises som noise (under threshold 2)"
  )
})

test_that("admission-heuristik tillader danish-comma decimaler", {
  count_parsed_numeric <- function(col) {
    if (is.numeric(col)) {
      return(sum(!is.na(col)))
    }
    parsed <- parse_danish_number(as.character(col))
    sum(!is.na(parsed))
  }

  df <- data.frame(
    date = c("Jan", "Feb"),
    v = c("12,5", "13,2"),
    stringsAsFactors = FALSE
  )
  nc <- vapply(df, count_parsed_numeric, integer(1))
  expect_true(any(nc >= 2L))
})
