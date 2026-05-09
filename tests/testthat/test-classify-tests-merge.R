# test-classify-tests-merge.R
# Cycle F H3 (Codex 2026-05-09): regression-tests for has_value()-baseret
# merge_with_existing() der bevarer manuelle felter ogsaa for unreviewed entries.
#
# Pre-fix: classify_tests_lib.R::merge_with_existing() returnerede silent auto
# entry hvis existing$reviewed != TRUE -> manuel rationale/merge_with/handling
# blev silent overskrevet ved hver classify_tests-koersel.
#
# Post-fix: field-level merge bevarer manuelt-tilfoejede felter uafhaengigt
# af reviewed-flag.

lib_path <- testthat::test_path("..", "..", "dev", "classify_tests_lib.R")

skip_if_no_lib <- function() {
  testthat::skip_if_not(file.exists(lib_path), "classify_tests_lib.R ej fundet (R CMD check installeret-tree)")
}

source_lib <- function() {
  skip_if_no_lib()
  sys.source(lib_path, envir = parent.frame())
}

test_that("has_value handles NULL", {
  source_lib()
  expect_false(has_value(NULL))
})

test_that("has_value handles empty character", {
  source_lib()
  expect_false(has_value(character(0)))
  expect_false(has_value(""))
})

test_that("has_value handles scalar string", {
  source_lib()
  expect_true(has_value("hello"))
})

test_that("has_value handles multi-item character vector without crashing", {
  source_lib()
  # Tidligere implementation: is.character(x) && nzchar(x) errored med
  # "the condition has length > 1" paa multi-item vektor
  expect_true(has_value(c("a", "b")))
})

test_that("has_value handles list", {
  source_lib()
  expect_true(has_value(list("a", "b")))
  expect_false(has_value(list()))
})

test_that("has_value handles all-NA vector", {
  source_lib()
  expect_false(has_value(c(NA_character_, NA_character_)))
  expect_true(has_value(c(NA_character_, "x")))
})

test_that("merge_with_existing preserves manual rationale on unreviewed entry", {
  source_lib()
  auto <- list(list(
    file = "test-foo.R", audit_category = "unit",
    type = "unit", handling = "keep"
  ))
  existing <- list(files = list(list(
    file = "test-foo.R", audit_category = "old-category",
    type = "unit", handling = "keep",
    rationale = "manuel rationale",
    reviewed = FALSE
  )))
  result <- merge_with_existing(auto, existing)
  expect_equal(result[[1]]$rationale, "manuel rationale")
  # audit_category SKAL synces fra auto (kommer fra audit-data)
  expect_equal(result[[1]]$audit_category, "unit")
})

test_that("merge_with_existing preserves multi-item merge_with field", {
  source_lib()
  auto <- list(list(
    file = "test-bar.R", audit_category = "unit",
    type = "unit", handling = "merge-in-phase-2"
  ))
  existing <- list(files = list(list(
    file = "test-bar.R", audit_category = "merge-target",
    type = "unit", handling = "merge-in-phase-2",
    merge_with = c("test-baz.R", "test-qux.R"),
    rationale = "consolidated",
    reviewed = FALSE
  )))
  result <- merge_with_existing(auto, existing)
  expect_equal(result[[1]]$merge_with, c("test-baz.R", "test-qux.R"))
  expect_equal(result[[1]]$rationale, "consolidated")
})

test_that("merge_with_existing preserves manually changed handling field", {
  source_lib()
  auto <- list(list(
    file = "test-h.R", audit_category = "unit",
    type = "unit", handling = "fix-in-phase-3"
  ))
  existing <- list(files = list(list(
    file = "test-h.R", audit_category = "old",
    type = "unit",
    handling = "keep", # manuelt aendret fra auto-suggestion
    reviewed = FALSE
  )))
  result <- merge_with_existing(auto, existing)
  expect_equal(result[[1]]$handling, "keep")
})

test_that("merge_with_existing returns auto unchanged for new entries", {
  source_lib()
  auto <- list(list(
    file = "test-new.R", audit_category = "unit",
    type = "unit", handling = "keep"
  ))
  existing <- list(files = list(list(
    file = "test-other.R", reviewed = TRUE
  )))
  result <- merge_with_existing(auto, existing)
  expect_equal(result[[1]]$file, "test-new.R")
})

test_that("merge_with_existing handles NULL existing manifest", {
  source_lib()
  auto <- list(list(file = "test.R", audit_category = "unit"))
  expect_identical(merge_with_existing(auto, NULL), auto)
  expect_identical(merge_with_existing(auto, list(files = NULL)), auto)
})

test_that("merge_with_existing preserves reviewer + reviewed_date on unreviewed entry", {
  source_lib()
  auto <- list(list(
    file = "test-r.R", audit_category = "unit",
    type = "unit", handling = "keep"
  ))
  existing <- list(files = list(list(
    file = "test-r.R", audit_category = "old",
    type = "unit", handling = "keep",
    reviewer = "alice",
    reviewed_date = "2026-04-01",
    reviewed = FALSE # ej afsluttet review, men reviewer-info eksisterer
  )))
  result <- merge_with_existing(auto, existing)
  expect_equal(result[[1]]$reviewer, "alice")
  expect_equal(result[[1]]$reviewed_date, "2026-04-01")
})
