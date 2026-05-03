# Unit tests for fct_spc_bfh_signals.R::classify_error_source()
# (M1 / #455). Funktionen mangler direkte tests trods at den driver
# user-facing error-attribution + escalate-flag.

test_that("classify_error_source: BFHcharts-error -> kilde 'BFHcharts' + escalate=TRUE", {
  err <- simpleError("Error in BFHcharts::bfh_qic(): segfault i calculate_limits()")
  result <- classify_error_source(err)

  expect_equal(result$source, "BFHcharts")
  expect_equal(result$component, "BFH_INTEGRATION")
  expect_true(result$escalate)
  expect_match(result$user_message, "Kontakt Dataenheden")
})

test_that("classify_error_source: bfh_qic-mention uden BFHcharts:: rammer også BFHcharts-branch", {
  err <- simpleError("bfh_qic() failed during rendering")
  result <- classify_error_source(err)

  expect_equal(result$source, "BFHcharts")
})

test_that("classify_error_source: validation-error -> kilde 'biSPCharts' + ej escalate", {
  err <- simpleError("Missing required column 'denominator'")
  result <- classify_error_source(err)

  expect_equal(result$source, "biSPCharts")
  expect_equal(result$component, "BFH_VALIDATION")
  expect_false(result$escalate)
  expect_match(result$user_message, "Konfigurationsfejl")
})

test_that("classify_error_source: required parameter-fejl -> biSPCharts validation", {
  err <- simpleError("Required parameter 'chart_type' missing from call")
  result <- classify_error_source(err)

  expect_equal(result$source, "biSPCharts")
})

test_that("classify_error_source: data-empty-fejl -> kilde 'User Data' + ej escalate", {
  err <- simpleError("Data is empty - no rows to process")
  result <- classify_error_source(err)

  expect_equal(result$source, "User Data")
  expect_equal(result$component, "BFH_SERVICE")
  expect_false(result$escalate)
  expect_match(result$user_message, "Datafejl")
})

test_that("classify_error_source: insufficient data-fejl -> kilde 'User Data'", {
  err <- simpleError("insufficient data for SPC chart (need at least 6 points)")
  result <- classify_error_source(err)

  expect_equal(result$source, "User Data")
})

test_that("classify_error_source: ukendt fejl -> kilde 'Unknown' + escalate=TRUE", {
  err <- simpleError("Some completely unknown error from a dependency")
  result <- classify_error_source(err)

  expect_equal(result$source, "Unknown")
  expect_true(result$escalate)
  expect_match(result$user_message, "uventet fejl")
})

test_that("classify_error_source: ALDRIG returnerer NULL — fallback ved exception", {
  # Hvis classify_error_source() selv kaster (fx pga. malformed condition),
  # skal safe_operation-fallback returnere et fully-formed list-objekt
  # — ikke NULL. Pas et objekt der får conditionMessage til at fejle.
  weird <- structure(list(), class = "condition") # mangler $message

  result <- classify_error_source(weird)
  expect_false(is.null(result))
  expect_named(result, c("source", "component", "actionable_by", "escalate", "user_message"),
    ignore.order = TRUE
  )
})
