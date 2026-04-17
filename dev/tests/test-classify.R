# Tests for dev/classify_tests.R + dev/classify_tests_lib.R
# Kør: Rscript dev/tests/run_tests.R

library(testthat)

# Source library robustly — virker uanset working dir
.resolve_lib_path <- function() {
  candidates <- c(
    "dev/classify_tests_lib.R",
    file.path("..", "..", "dev", "classify_tests_lib.R"),
    file.path("..", "classify_tests_lib.R")
  )
  hit <- Filter(file.exists, candidates)
  if (length(hit) == 0) {
    stop("Kan ikke finde classify_tests_lib.R. Kør fra project-root.")
  }
  hit[[1]]
}
source(.resolve_lib_path())

test_that("VALID_TYPES indeholder alle 7 type-værdier", {
  expect_length(VALID_TYPES, 7)
  expect_true(all(c("policy-guard", "unit", "integration", "e2e",
                    "benchmark", "snapshot", "fixture-based") %in% VALID_TYPES))
})

test_that("VALID_HANDLINGS indeholder alle 7 handling-værdier", {
  expect_length(VALID_HANDLINGS, 7)
  expect_true(all(c("keep", "fix-in-phase-3", "merge-in-phase-2", "archive",
                    "rewrite", "blocked-by-change-1", "needs-triage") %in% VALID_HANDLINGS))
})

test_that("`%||%` returnerer b når a er NULL", {
  expect_equal(NULL %||% "fallback", "fallback")
  expect_equal("actual" %||% "fallback", "actual")
})

# ---- auto_classify_type ----

test_that("auto_classify_type identifies e2e via skip_on_ci()", {
  result <- auto_classify_type(
    "test-foo.R",
    file_contents = "test_that('x', { skip_on_ci(); app <- AppDriver$new() })"
  )
  expect_equal(result, "e2e")
})

test_that("auto_classify_type identifies e2e via shinytest2", {
  result <- auto_classify_type(
    "test-foo.R",
    file_contents = "library(shinytest2); skip_if_not_installed('shinytest2')"
  )
  expect_equal(result, "e2e")
})

test_that("auto_classify_type identifies benchmark from filename", {
  expect_equal(
    auto_classify_type("test-performance-benchmarks.R", ""),
    "benchmark"
  )
})

test_that("auto_classify_type identifies snapshot via expect_snapshot", {
  result <- auto_classify_type(
    "test-foo.R",
    file_contents = "test_that('x', { expect_snapshot(plot_output()) })"
  )
  expect_equal(result, "snapshot")
})

test_that("auto_classify_type identifies policy-guard from filename pattern", {
  expect_equal(auto_classify_type("test-namespace-integrity.R", ""), "policy-guard")
  expect_equal(auto_classify_type("test-dependency-namespace.R", ""), "policy-guard")
  expect_equal(auto_classify_type("test-logging-debug-cat.R", ""), "policy-guard")
})

test_that("auto_classify_type identifies integration from filename pattern", {
  expect_equal(auto_classify_type("test-mod-export.R", ""), "integration")
  expect_equal(auto_classify_type("test-e2e-workflows.R", ""), "integration")
})

test_that("auto_classify_type identifies fixture-based via test_path calls", {
  result <- auto_classify_type(
    "test-foo.R",
    file_contents = 'data <- read.csv(test_path("fixtures/data.csv"))'
  )
  expect_equal(result, "fixture-based")
})

test_that("auto_classify_type defaults to unit", {
  expect_equal(
    auto_classify_type("test-utils-parse.R", "test_that('x', { expect_equal(1, 1) })"),
    "unit"
  )
})

test_that("auto_classify_type e2e vinder over integration-filnavn", {
  result <- auto_classify_type(
    "test-mod-export.R",
    file_contents = "skip_on_ci(); app <- AppDriver$new()"
  )
  expect_equal(result, "e2e")
})
