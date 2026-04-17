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
