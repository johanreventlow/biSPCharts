# test-lintr-no-test-source-read.R
# Cycle F H2 + M3 (Codex 2026-05-09): unit-test af custom lintr-regel
# der detekterer source-tree-reads i test-filer.
#
# Forhindrer recurrence af readLines(test_path("..", "..", "R", ...))-pattern
# der virker i devtools::test() men fejler/skipper i R CMD check.

linter_path <- testthat::test_path("..", "..", "dev", "lintr_no_test_source_read.R")

# Skip-betingelser:
#  - linter-fil mangler (R CMD check installeret-tree har ej dev/-mappen)
#  - lintr-pakken ikke installeret (lintr er kun dev-dep, ej i CI-Imports)
skip_if_no_linter <- function() {
  testthat::skip_if_not_installed("lintr")
  testthat::skip_if_not(file.exists(linter_path), "linter-fil ej fundet (R CMD check installeret-tree)")
}

run_linter <- function(code) {
  skip_if_no_linter()
  sys.source(linter_path, envir = environment())
  tmp <- tempfile(fileext = ".R")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(code, tmp)
  lintr::lint(tmp, linters = list(no_test_source_read_linter()))
}

test_that("Pattern A: direct readLines(test_path()) flagged", {
  lints <- run_linter('
test_that("a", {
  source_lines <- readLines(test_path("..", "..", "R", "foo.R"))
})')
  expect_gt(length(lints), 0)
})

test_that("Pattern B: variable-assigned readLines(var) flagged when var = test_path('..', ...)", {
  lints <- run_linter('
test_that("b", {
  src <- testthat::test_path("..", "..", "R", "foo.R")
  src_lines <- readLines(src)
})')
  expect_gt(length(lints), 0)
})

test_that("Pattern C: hardcoded path readLines('../../R/foo.R') flagged", {
  lints <- run_linter('
test_that("c", {
  txt <- readLines("../../R/foo.R")
})')
  expect_gt(length(lints), 0)
})

test_that("Negative: body() introspection passes (no lint)", {
  lints <- run_linter('
test_that("ok", {
  body_text <- paste(deparse(body(my_fn)), collapse = "\\n")
})')
  expect_length(lints, 0)
})

test_that("Negative: legitimate test_path('fixtures', ...) passes (no lint)", {
  lints <- run_linter('
test_that("fixture", {
  data <- readLines(test_path("fixtures", "data.csv"))
})')
  expect_length(lints, 0)
})

test_that("Negative: test_path used without read passes (no lint)", {
  lints <- run_linter('
test_that("nothing", {
  src <- testthat::test_path("..", "..", "R", "foo.R")
  expect_true(file.exists(src))
})')
  expect_length(lints, 0)
})

test_that("Multiple read functions detected: readRDS, scan, read.csv", {
  for (fn in c("readRDS", "scan", "read.csv", "read.dcf", "read.table")) {
    lints <- run_linter(sprintf('
test_that("multi", {
  src <- test_path("..", "..", "R", "foo.R")
  data <- %s(src)
})', fn))
    expect_gt(length(lints), 0,
      label = sprintf("Function %s should be detected", fn)
    )
  }
})
