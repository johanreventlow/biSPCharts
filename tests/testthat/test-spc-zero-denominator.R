# test-spc-zero-denominator.R
# Tests for n=0-rækker: konverteres til NA, crasher ikke pipeline.
# Spec: openspec/changes/fix-spc-domain-correctness/specs/spc-facade/spec.md

library(testthat)

make_u_data <- function(y, n) {
  data.frame(
    dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = length(y)),
    infections = y,
    patients = n
  )
}

test_that("U-chart: n=0-rækker crasher IKKE pipelinen", {
  # 12 rækker, 1 har n=0 -- forventning: ingen exception, pipeline returnerer chart
  n_vals <- c(100, 120, 0, 110, 95, 105, 98, 112, 88, 102, 115, 97)
  y_vals <- c(2, 3, 0, 1, 2, 4, 1, 3, 2, 2, 3, 1)
  d <- make_u_data(y_vals, n_vals)

  # Validate-steget skal tillade n=0 at passere (håndteres som NA i prepare-steget)
  expect_no_error(
    validate_spc_request(d, x_var = "dato", y_var = "infections", chart_type = "u", n_var = "patients")
  )
})

test_that("U-chart: alle n=0 kaster spc_input_error fra validate", {
  # Alle nævnere er nul -- ingen brugbare data
  d <- make_u_data(y = c(1, 2, 3), n = c(0, 0, 0))
  # validate_spc_request checker <= 0 for alle rækker -> fejl
  expect_error(
    validate_spc_request(d, x_var = "dato", y_var = "infections", chart_type = "u", n_var = "patients"),
    class = "spc_input_error"
  )
})

test_that("n=0 passerer validate (konverteres til NA i data-steget, ikke fejl i validate)", {
  # Kun EN n=0 -- validate skal IKKE kaste fejl (mix af 0 og positive er OK)
  d <- make_u_data(y = c(1, 2, 0, 3), n = c(100, 110, 0, 95))
  # Forventer ingen fejl fra validate_spc_request
  expect_no_error(
    validate_spc_request(d, x_var = "dato", y_var = "infections", chart_type = "u", n_var = "patients")
  )
})
