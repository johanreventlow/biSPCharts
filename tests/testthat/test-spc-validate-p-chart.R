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

test_that("P-chart med y > n tillades (BFHcharts >= 0.19.0)", {
  # BFHcharts 0.19.0 tillader proportion > 1 som outlier-signal over ucl=1.
  # biSPCharts check #15 fjernet for cross-package konsistens.
  d <- make_p_data(y = c(5, 15, 3), n = c(10, 10, 10))
  expect_no_error(
    validate_spc_request(d, x_var = "dato", y_var = "y", chart_type = "p", n_var = "n")
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

# P'-chart (pp) er ej supporteret i biSPCharts UI — test fjernet ved
# fjernelse af check #15. Den oprindelige test passerede falsk positivt
# (spc_input_error kom fra check #5 'invalid chart_type', ikke y>n).

test_that("U-chart med y > n er tilladt (rate, ikke proportion)", {
  d <- make_p_data(y = c(15, 12, 18), n = c(10, 10, 10))
  # U-chart: rate kan overstige 1 per denominatorenhed -- ingen fejl
  expect_no_error(
    validate_spc_request(d, x_var = "dato", y_var = "y", chart_type = "u", n_var = "n")
  )
})
