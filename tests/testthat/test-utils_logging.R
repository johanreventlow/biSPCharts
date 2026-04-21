# test-utils_logging.R
# Regressionstests for utils_logging-funktioner og korrekt signatur-brug

test_that("log_warn accepterer session_id kun via details-parameter (regression #291)", {
  # session_id er ikke et top-level argument i log_warn() — det skal pakkes i details
  expect_no_error(
    log_warn(
      "test message",
      .context = "TEST",
      details = list(session_id = "abc123")
    )
  )
})

test_that("log_warn afviser session_id som top-level argument (regression #291)", {
  # log_warn har ingen ... — et ukendt top-level arg giver en fejl
  expect_error(
    log_warn(
      "test message",
      .context = "TEST",
      session_id = "abc123"
    ),
    regexp = "ubrugt argument|unused argument"
  )
})

test_that("log_info accepterer details som liste", {
  expect_no_error(
    log_info(
      "test info",
      .context = "TEST",
      details = list(session_id = "abc123", rows = 42L)
    )
  )
})

test_that("log_error accepterer details som liste", {
  expect_no_error(
    log_error(
      "test error",
      .context = "TEST",
      details = list(session_id = "abc123")
    )
  )
})
