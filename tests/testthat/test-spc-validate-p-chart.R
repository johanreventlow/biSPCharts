# test-spc-validate-p-chart.R
# Tests for P/P'-chart numerator <= denominator validering.
# Spec: openspec/changes/fix-spc-domain-correctness/specs/spc-facade/spec.md

library(testthat)

# Hjælper: minimal valid data til p-chart
make_p_data <- function(y, n) {
  data.frame(
    dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = length(y)),
    y = y,
    n = n
  )
}

test_that("P-chart med y > n kaster spc_input_error", {
  # Række 2: y=15 > n=10 --> ugyldig proportion
  d <- make_p_data(y = c(5, 15, 3), n = c(10, 10, 10))
  expect_error(
    validate_spc_request(d, x_var = "dato", y_var = "y", chart_type = "p", n_var = "n"),
    class = "spc_input_error",
    info = "y > n skal kaste spc_input_error for p-chart"
  )
})

test_that("P-chart med y > n fejlbesked er dansk og refererer til ugyldig række", {
  d <- make_p_data(y = c(5, 15, 3), n = c(10, 10, 10))
  err <- tryCatch(
    validate_spc_request(d, x_var = "dato", y_var = "y", chart_type = "p", n_var = "n"),
    error = function(e) e
  )
  expect_true(
    grepl("proportion", err$message, ignore.case = TRUE) ||
      grepl("nævner", err$message, ignore.case = TRUE) ||
      grepl("tæller", err$message, ignore.case = TRUE),
    info = "Fejlbesked skal referere til proportion-problem"
  )
})

test_that("P-chart med y == n (100%) er gyldig", {
  d <- make_p_data(y = c(10, 10, 10), n = c(10, 10, 10))
  # Ingen fejl forventet
  expect_no_error(
    validate_spc_request(d, x_var = "dato", y_var = "y", chart_type = "p", n_var = "n")
  )
})

test_that("P-chart med y < n er gyldig", {
  d <- make_p_data(y = c(3, 5, 8), n = c(10, 10, 10))
  expect_no_error(
    validate_spc_request(d, x_var = "dato", y_var = "y", chart_type = "p", n_var = "n")
  )
})

test_that("P'-chart med y > n kaster spc_input_error", {
  d <- make_p_data(y = c(5, 12, 3), n = c(10, 10, 10))
  expect_error(
    validate_spc_request(d, x_var = "dato", y_var = "y", chart_type = "pp", n_var = "n"),
    class = "spc_input_error"
  )
})

test_that("U-chart med y > n er tilladt (rate, ikke proportion)", {
  d <- make_p_data(y = c(15, 12, 18), n = c(10, 10, 10))
  # U-chart: rate kan overstige 1 per denominatorenhed -- ingen fejl
  expect_no_error(
    validate_spc_request(d, x_var = "dato", y_var = "y", chart_type = "u", n_var = "n")
  )
})
