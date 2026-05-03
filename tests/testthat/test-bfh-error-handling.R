# test-bfh-error-handling.R
# Comprehensive error handling tests for BFHchart integration
#
# Tests error attribution, structured logging, error classification,
# and production safeguards for BFHchart service layer.

library(testthat)
library(mockery)

# Test data setup
create_test_data <- function(n = 30) {
  data.frame(
    dato = seq.Date(Sys.Date() - (n - 1), Sys.Date(), by = "day"),
    vaerdi = rnorm(n, mean = 10, sd = 2),
    n_column = rep(100, n)
  )
}

# Test: Error source classification
test_that("classify_error_source correctly attributes BFHcharts errors", {
  # BFHcharts API error
  bfh_error <- simpleError("BFHcharts::create_spc_chart failed: invalid parameter")
  classification <- classify_error_source(bfh_error)

  expect_equal(classification$source, "BFHcharts")
  expect_equal(classification$component, "BFH_INTEGRATION")
  expect_true(classification$escalate)
  expect_match(classification$user_message, "SPC beregning")
})

test_that("classify_error_source correctly attributes biSPCharts validation errors", {
  # Validation error
  validation_error <- simpleError("Missing required columns: x_column")
  classification <- classify_error_source(validation_error)

  expect_equal(classification$source, "biSPCharts")
  expect_equal(classification$component, "BFH_VALIDATION")
  expect_false(classification$escalate)
  expect_match(classification$user_message, "Konfigurationsfejl")
})

test_that("classify_error_source correctly attributes user data errors", {
  # Data error
  data_error <- simpleError("Data is NULL or empty")
  classification <- classify_error_source(data_error)

  expect_equal(classification$source, "User Data")
  expect_equal(classification$component, "BFH_SERVICE")
  expect_false(classification$escalate)
  expect_match(classification$user_message, "Datafejl")
})

test_that("classify_error_source handles unknown errors gracefully", {
  # Unknown error
  unknown_error <- simpleError("Something completely unexpected happened")
  classification <- classify_error_source(unknown_error)

  expect_equal(classification$source, "Unknown")
  expect_equal(classification$component, "BFH_SERVICE")
  expect_true(classification$escalate)
  expect_match(classification$user_message, "uventet fejl")
})

# Note: sanitize_log_details + log_with_throttle blev fjernet i logging-
# refactor. Ansvaret er flyttet til log_info/log_warn/log_error (strukturerer
# details internt) og logger-backend via options(spc.log.level) +
# .context-filtrering. Tests for de fjernede funktioner er slettet (#428).

# Test: Input-validering kaster fejl (opdateret efter #240)
# Tidligere forventede testene NULL-return via safe_operation, men #240 indførte
# eksplicit validate_spc_inputs() der kaster stop() FØR safe_operation-wrapper
# — fejl propagerer nu til caller med danske fejlbeskeder.
test_that("compute_spc_results_bfh handles missing required parameters", {
  # Missing data parameter skal kaste fejl
  expect_error(
    compute_spc_results_bfh(
      data = NULL,
      x_var = "dato",
      y_var = "vaerdi",
      chart_type = "run"
    ),
    "data parameter er p.*kr.*vet"
  )
})

test_that("compute_spc_results_bfh handles invalid chart type", {
  data <- create_test_data()

  expect_error(
    compute_spc_results_bfh(
      data = data,
      x_var = "dato",
      y_var = "vaerdi",
      chart_type = "invalid_type"
    ),
    "chart_type.*invalid|Must be one of"
  )
})

test_that("compute_spc_results_bfh handles empty data gracefully", {
  empty_data <- data.frame()

  expect_error(
    compute_spc_results_bfh(
      data = empty_data,
      x_var = "dato",
      y_var = "vaerdi",
      chart_type = "run"
    ),
    "r.*kker fundet|empty dataset|empty"
  )
})

test_that("compute_spc_results_bfh handles insufficient data points", {
  # Only 2 points (minimum is 3 efter #241)
  small_data <- create_test_data(n = 2)

  expect_error(
    compute_spc_results_bfh(
      data = small_data,
      x_var = "dato",
      y_var = "vaerdi",
      chart_type = "run"
    ),
    "For f.* datapunkter|too few|insufficient"
  )
})

test_that("compute_spc_results_bfh requires denominator for rate charts", {
  data <- create_test_data()

  # P-chart without n_var should fail
  expect_error(
    compute_spc_results_bfh(
      data = data,
      x_var = "dato",
      y_var = "vaerdi",
      chart_type = "p",
      n_var = NULL # Missing denominator
    ),
    "n_var.*required|denominator.*required"
  )
})

# Test: Error logging integration
test_that("Errors are logged with correct component tags", {
  # Trigger validation error (missing column)
  data <- create_test_data()
  expect_error(
    suppressMessages(compute_spc_results_bfh(
      data = data,
      x_var = "missing_column",
      y_var = "vaerdi",
      chart_type = "run"
    )),
    "missing_column.*ikke fundet|missing column"
  )

  # Verify error classification for this type of error
  column_error <- simpleError("Missing required columns: missing_column")
  classification <- classify_error_source(column_error)
  expect_equal(classification$component, "BFH_VALIDATION")
})

# Note: PII-filtrerings-test er slettet (#428) — sanitize_log_details fjernet i
# logging-refactor; PII-filtrering sker nu implicit i log_*-kald og dækkes af
# test-logging-*.R.

test_that("Error messages are actionable and user-friendly", {
  # Test various error scenarios
  data <- create_test_data()

  # NB: tidligere kald til validate_chart_type_bfh fjernet (#451) — funktionen
  # var dead code, faktisk validering sker i validate_spc_request().
  # Her testes alene at error_classifier mapper invalid-chart-type-strings
  # korrekt til "biSPCharts" / "Konfigurationsfejl".

  # Test error classification directly
  chart_error <- simpleError("Invalid chart_type: 'not_a_chart_type'. Must be one of: run, i, mr")
  classification1 <- classify_error_source(chart_error)

  # This should be classified as biSPCharts (validation error)
  expect_equal(classification1$source, "biSPCharts")
  expect_match(classification1$user_message, "Konfigurationsfejl")

  # Missing column error classification
  column_error <- simpleError("Missing required columns: x_column")
  classification2 <- classify_error_source(column_error)

  expect_equal(classification2$source, "biSPCharts")
  expect_match(classification2$user_message, "Konfigurationsfejl")
  expect_match(classification2$actionable_by, "biSPCharts developer")
})

# Test: Log volume control
test_that("Debug mode logging is controlled by environment variable", {
  # Save original log level
  original_level <- Sys.getenv("SPC_LOG_LEVEL", unset = "INFO")

  # Set to ERROR level (minimal logging)
  Sys.setenv(SPC_LOG_LEVEL = "ERROR")

  # Verify log level is set correctly
  expect_equal(get_log_level(), LOG_LEVELS$ERROR)

  # Verify that debug logs are suppressed
  # log_debug should not output when level is ERROR
  expect_silent({
    log_debug("This should not be logged", .context = "TEST")
  })

  # Restore
  Sys.setenv(SPC_LOG_LEVEL = original_level)
})

test_that("Production log volume is acceptable", {
  # Save original log level
  original_level <- Sys.getenv("SPC_LOG_LEVEL", unset = "INFO")

  # Set to WARN level (production standard)
  Sys.setenv(SPC_LOG_LEVEL = "WARN")

  # Verify log level is set correctly
  expect_equal(get_log_level(), LOG_LEVELS$WARN)

  # Verify that debug and info logs are suppressed
  expect_silent({
    log_debug("Debug message", .context = "TEST")
    log_info("Info message", .context = "TEST")
  })

  # Warnings should still be logged
  # (We cannot easily test this without mocking cat, but we can verify the logic)
  expect_true(.should_log("WARN"))
  expect_true(.should_log("ERROR"))
  expect_false(.should_log("DEBUG"))
  expect_false(.should_log("INFO"))

  # Restore
  Sys.setenv(SPC_LOG_LEVEL = original_level)
})
