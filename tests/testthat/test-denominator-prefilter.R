# test-denominator-prefilter.R
# Tests for denominator pre-filter (issue #342)
# BFHcharts 0.9.0+ kaster hard error ved ugyldige n-værdier.
# Pre-filteret fjerner sådanne rækker FØR BFHcharts-kaldet.

# Hjælpefunktion: byg minimal p-chart testdata
make_p_data <- function(n_vals, y_vals = NULL, nrow = NULL) {
  if (is.null(nrow)) nrow <- length(n_vals)
  if (is.null(y_vals)) y_vals <- rep(1L, nrow)
  data.frame(
    dato = seq_len(nrow),
    taeller = y_vals,
    naevner = n_vals,
    stringsAsFactors = FALSE
  )
}

# --- generateSPCPlot pre-filter tests ----------------------------------------

test_that("pre-filter fjerner rækker med n == 0 for p-kort", {
  require_internal("generateSPCPlot", mode = "function")

  # 12 rækker: én har n == 0 → forventer 11 rækker i resultatet
  n_vals <- c(0L, rep(100L, 11))
  y_vals <- c(1L, rep(5L, 11))
  df <- make_p_data(n_vals, y_vals)

  config <- list(x_col = NULL, y_col = "taeller", n_col = "naevner")
  result <- generateSPCPlot(data = df, config = config, chart_type = "p")

  expect_equal(nrow(result$qic_data), 11)
})

test_that("pre-filter fjerner rækker med n < 0 for p-kort", {
  require_internal("generateSPCPlot", mode = "function")

  n_vals <- c(-5L, rep(100L, 11))
  y_vals <- c(1L, rep(5L, 11))
  df <- make_p_data(n_vals, y_vals)

  config <- list(x_col = NULL, y_col = "taeller", n_col = "naevner")
  result <- generateSPCPlot(data = df, config = config, chart_type = "p")

  expect_equal(nrow(result$qic_data), 11)
})

test_that("pre-filter fjerner rækker med n = Inf for u-kort", {
  require_internal("generateSPCPlot", mode = "function")

  n_vals <- c(Inf, rep(100, 11))
  y_vals <- c(1, rep(5, 11))
  df <- make_p_data(n_vals, y_vals)

  config <- list(x_col = NULL, y_col = "taeller", n_col = "naevner")
  result <- generateSPCPlot(data = df, config = config, chart_type = "u")

  expect_equal(nrow(result$qic_data), 11)
})

test_that("pre-filter fjerner rækker med n = NA for p-kort", {
  require_internal("generateSPCPlot", mode = "function")

  n_vals <- c(NA_real_, rep(100, 11))
  y_vals <- c(1, rep(5, 11))
  df <- make_p_data(n_vals, y_vals)

  config <- list(x_col = NULL, y_col = "taeller", n_col = "naevner")
  result <- generateSPCPlot(data = df, config = config, chart_type = "p")

  expect_equal(nrow(result$qic_data), 11)
})

test_that("pre-filter fjerner rækker med y > n for p-kort", {
  require_internal("generateSPCPlot", mode = "function")

  # Én række: y (10) > n (5) → ugyldig for P-chart
  n_vals <- c(5L, rep(100L, 11))
  y_vals <- c(10L, rep(5L, 11))
  df <- make_p_data(n_vals, y_vals)

  config <- list(x_col = NULL, y_col = "taeller", n_col = "naevner")
  result <- generateSPCPlot(data = df, config = config, chart_type = "p")

  expect_equal(nrow(result$qic_data), 11)
})

test_that("pre-filter sætter dropped_denominator_rows i metadata", {
  require_internal("generateSPCPlot", mode = "function")

  # 2 dårlige rækker: én n==0, én n<0
  n_vals <- c(0L, -3L, rep(100L, 10))
  y_vals <- c(1L, 1L, rep(5L, 10))
  df <- make_p_data(n_vals, y_vals)

  config <- list(x_col = NULL, y_col = "taeller", n_col = "naevner")
  result <- generateSPCPlot(data = df, config = config, chart_type = "p")

  expect_equal(result$metadata$dropped_denominator_rows, 2L)
})

test_that("pre-filter påvirker IKKE data med udelukkende gyldige n-værdier", {
  require_internal("generateSPCPlot", mode = "function")

  n_vals <- rep(100L, 12)
  y_vals <- rep(5L, 12)
  df <- make_p_data(n_vals, y_vals)

  config <- list(x_col = NULL, y_col = "taeller", n_col = "naevner")
  result <- generateSPCPlot(data = df, config = config, chart_type = "p")

  expect_equal(nrow(result$qic_data), 12)
  expect_null(result$metadata$dropped_denominator_rows)
})

# --- validate_spc_request check #12 tests ------------------------------------

test_that("validate_spc_request kaster spc_input_error ved n <= 0 (negativ)", {
  df <- data.frame(dato = 1:10, taeller = 1:10, naevner = c(-1L, rep(100L, 9)))
  expect_error(
    validate_spc_request(df, "dato", "taeller", "p", n_var = "naevner"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request kaster spc_input_error ved n = Inf", {
  df <- data.frame(dato = 1:10, taeller = 1:10, naevner = c(Inf, rep(100, 9)))
  expect_error(
    validate_spc_request(df, "dato", "taeller", "p", n_var = "naevner"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request tillader n == 0 (konverteres til NA i prepare-steget, ikke fejl)", {
  # Phase 7 fix: n=0 er gyldig klinisk observation ("ingen patienter denne måned").
  # Validate-steget kaster IKKE fejl -- rækken fjernes i data-processing-steget.
  # NB: tæller=0 for n=0-rækken så proportions-check (y <= n) ikke fejler separat.
  df <- data.frame(dato = 1:10, taeller = c(0L, 1:9), naevner = c(0L, rep(100L, 9)))
  # Kun én n=0 ud af 10 -- resterende 9 er brugbare, ingen fejl
  expect_no_error(
    validate_spc_request(df, "dato", "taeller", "p", n_var = "naevner")
  )
})

test_that("validate_spc_request fejlbesked nævner < 0 eller uendelig", {
  # Negative nævnere og Inf er stadig ugyldige -- n=0 er dog tilladt (behandles som NA)
  df <- data.frame(dato = 1:10, taeller = 1:10, naevner = c(Inf, rep(100, 9)))
  expect_error(
    validate_spc_request(df, "dato", "taeller", "p", n_var = "naevner"),
    regexp = "< 0 eller uendelig"
  )
})

test_that("validate_spc_request accepterer p-kort med alle positive n-værdier", {
  df <- data.frame(dato = 1:10, taeller = 1:10, naevner = rep(100L, 10))
  req <- validate_spc_request(df, "dato", "taeller", "p", n_var = "naevner")
  expect_s3_class(req, "spc_request")
})
