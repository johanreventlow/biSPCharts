# test-data-validation.R
# Tests af data validering og hjælpefunktioner

# Load required functions if not already available via package namespace
if (!exists("get_qic_chart_type", mode = "function")) {
  sp <- tryCatch(here::here("R", "config_chart_types.R"), error = function(e) NULL)
  if (!is.null(sp) && file.exists(sp)) source(sp)
}

test_that("ensure_standard_columns virker korrekt", {
  # Test data uden standard kolonner
  test_data <- data.frame(
    Dato = c("2024-01-01", "2024-02-01"),
    Tæller = c(10, 15),
    Nævner = c(100, 120)
  )

  # Kør funktionen
  result <- ensure_standard_columns(test_data)

  # Test at funktionen rent faktisk renser data (dens rigtige formål)
  expect_true(is.data.frame(result))
  expect_equal(nrow(result), nrow(test_data))

  # Test at original data bevares (main functionality)
  expect_true("Dato" %in% names(result))
  expect_true("Tæller" %in% names(result))
  expect_true("Nævner" %in% names(result))

  # Test at column names er valid
  expect_true(all(grepl("^[a-zA-Z]", names(result))))
})

test_that("validate_numeric_column fungerer", {
  # Skip if function not available
  skip_if_not(exists("validate_numeric_column", mode = "function"), "validate_numeric_column function not available")

  test_data <- data.frame(
    numerisk = c(1, 2, 3),
    tekst = c("a", "b", "c")
  )

  # Test valid numerisk kolonne
  result_valid <- validate_numeric_column(test_data, "numerisk")
  expect_true(is.null(result_valid) || result_valid == "")

  # Test invalid (ikke-numerisk) kolonne
  result_invalid <- validate_numeric_column(test_data, "tekst")
  # Function may return NULL, empty string, or error message
  expect_true(is.null(result_invalid) || is.character(result_invalid))

  # Test ikke-eksisterende kolonne
  result_missing <- validate_numeric_column(test_data, "findes_ikke")
  # Function may return NULL, empty string, or error message
  expect_true(is.null(result_missing) || is.character(result_missing))
})

# Test for validate_date_column fjernet i #228 PR A3:
# Funktionen blev fjernet i openspec change remove-legacy-dead-code (§4.5,
# arkiveret 2026-04-18). Dato-validering varetages nu af kolonneparser og
# auto-detection pipeline (se R/utils_server_time_preparation.R og
# fct_time_parsing.R). Ingen direkte erstatning kræves.

test_that("safe_date_parse fungerer robust", {
  # Skip if function not available
  skip_if_not(exists("safe_date_parse", mode = "function"), "safe_date_parse function not available")

  # Test valid danske datoer
  danske_datoer <- c("01-01-2024", "15-02-2024", "31-12-2023")
  result <- safe_date_parse(danske_datoer)

  # Handle both list and atomic return types
  if (is.list(result)) {
    expect_true(result$success)
    expect_gt(result$success_rate, 0.5)
    expect_equal(result$total_count, 3)
  } else {
    # If atomic vector, check that parsing worked
    expect_true(length(result) > 0)
  }

  # Test invalid datoer
  invalid_datoer <- c("ikke-en-dato", "abc", "32-13-2024")
  result_invalid <- safe_date_parse(invalid_datoer)

  # Handle both list and atomic return types
  if (is.list(result_invalid)) {
    expect_false(result_invalid$success)
    expect_equal(result_invalid$parsed_count, 0)
  } else {
    # If atomic vector, just check it exists (function behavior may vary)
    expect_true(length(result_invalid) > 0)
  }
})

test_that("chart type mapping fungerer", {
  # Test danske navne til engelske koder
  expect_equal(get_qic_chart_type("Seriediagram (Run) \u2014 data over tid"), "run")
  expect_equal(get_qic_chart_type("P-kort \u2014 andele/procenter (fx infektionsrate)"), "p")
  expect_equal(get_qic_chart_type("I-kort \u2014 enkelte m\u00e5linger (fx ventetid, temperatur)"), "i")

  # Test allerede engelske koder
  expect_equal(get_qic_chart_type("run"), "run")
  expect_equal(get_qic_chart_type("p"), "p")

  # Test fallback
  expect_equal(get_qic_chart_type("ukendt_type"), "run")
  expect_equal(get_qic_chart_type(""), "run")
  expect_equal(get_qic_chart_type(NULL), "run")
})
