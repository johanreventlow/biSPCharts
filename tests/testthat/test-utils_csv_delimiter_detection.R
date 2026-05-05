# test-utils_csv_delimiter_detection.R
# Direct contract tests for detect_csv_delimiter().

write_delimiter_probe <- function(lines) {
  path <- tempfile(fileext = ".csv")
  writeLines(lines, path)
  path
}

test_that("detect_csv_delimiter prefers semicolon CSV as Danish default", {
  require_internal("detect_csv_delimiter", mode = "function")

  path <- write_delimiter_probe(c(
    "Date;Count;Denominator",
    "2024-01-01;10,5;100",
    "2024-02-01;11,5;120"
  ))
  on.exit(unlink(path), add = TRUE)

  result <- detect_csv_delimiter(path)

  expect_true(result$parseable)
  expect_equal(result$strategy, "semikolon")
  expect_equal(result$delimiter, ";")
  expect_equal(result$ncol, 3L)
  expect_equal(result$nrow, 2L)
})

test_that("detect_csv_delimiter handles comma CSV with point decimals", {
  require_internal("detect_csv_delimiter", mode = "function")

  path <- write_delimiter_probe(c(
    "Date,Count,Denominator",
    "2024-01-01,10.5,100",
    "2024-02-01,11.5,120"
  ))
  on.exit(unlink(path), add = TRUE)

  result <- detect_csv_delimiter(path)

  expect_true(result$parseable)
  expect_equal(result$delimiter, ",")
  expect_equal(result$ncol, 3L)
  expect_equal(result$nrow, 2L)
})

test_that("detect_csv_delimiter handles tab-separated CSV through auto-detect", {
  require_internal("detect_csv_delimiter", mode = "function")

  path <- write_delimiter_probe(c(
    "Date\tCount\tDenominator",
    "2024-01-01\t10,5\t100",
    "2024-02-01\t11,5\t120"
  ))
  on.exit(unlink(path), add = TRUE)

  result <- detect_csv_delimiter(path)

  expect_true(result$parseable)
  expect_equal(result$strategy, "auto-detect")
  expect_equal(result$delimiter, "\t")
  expect_equal(result$ncol, 3L)
  expect_equal(result$nrow, 2L)
})

test_that("detect_csv_delimiter rejects one-column content as not parseable", {
  require_internal("detect_csv_delimiter", mode = "function")

  path <- write_delimiter_probe(c("OnlyOneColumn", "a", "b"))
  on.exit(unlink(path), add = TRUE)

  result <- detect_csv_delimiter(path)

  expect_false(result$parseable)
  expect_true(is.na(result$strategy))
  expect_true(is.na(result$delimiter))
  expect_equal(result$ncol, 0L)
  expect_equal(result$nrow, 0L)
})
