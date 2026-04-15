test_that("ANALYTICS_CONFIG har alle noedvendige felter", {
  expect_true(is.list(ANALYTICS_CONFIG))
  expect_true("consent_version" %in% names(ANALYTICS_CONFIG))
  expect_true("consent_max_age_days" %in% names(ANALYTICS_CONFIG))
  expect_true("log_retention_days" %in% names(ANALYTICS_CONFIG))
  expect_true("log_compress_after_days" %in% names(ANALYTICS_CONFIG))
  expect_true("pin_name" %in% names(ANALYTICS_CONFIG))
  expect_true("enabled" %in% names(ANALYTICS_CONFIG))
})

test_that("ANALYTICS_CONFIG har korrekte typer", {
  expect_type(ANALYTICS_CONFIG$consent_version, "integer")
  expect_type(ANALYTICS_CONFIG$consent_max_age_days, "integer")
  expect_type(ANALYTICS_CONFIG$log_retention_days, "integer")
  expect_type(ANALYTICS_CONFIG$log_compress_after_days, "integer")
  expect_type(ANALYTICS_CONFIG$pin_name, "character")
  expect_type(ANALYTICS_CONFIG$enabled, "logical")
})

test_that("ANALYTICS_CONFIG har fornuftige defaults", {
  expect_equal(ANALYTICS_CONFIG$consent_version, 1L)
  expect_equal(ANALYTICS_CONFIG$consent_max_age_days, 365L)
  expect_equal(ANALYTICS_CONFIG$log_retention_days, 365L)
  expect_equal(ANALYTICS_CONFIG$log_compress_after_days, 90L)
  expect_equal(ANALYTICS_CONFIG$pin_name, "spc-analytics-logs")
  expect_true(ANALYTICS_CONFIG$enabled)
})

test_that("get_analytics_config() returnerer korrekt config", {
  config <- get_analytics_config()
  expect_true(is.list(config))
  expect_equal(config$consent_version, ANALYTICS_CONFIG$consent_version)
})
