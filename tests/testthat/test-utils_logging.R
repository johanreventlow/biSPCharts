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

# Secret-redaktion (#575) =====================================================

test_that("log_info redakterer nøgle-navne der matcher secret-mønster", {
  output <- capture.output(
    log_info(
      "test",
      .context = "TEST",
      details = list(api_key = "super_hemmeligt", rows = 42L)
    )
  )
  expect_false(grepl("super_hemmeligt", paste(output, collapse = "")),
    info = "api_key-værdien må ikke fremgå af log-output"
  )
  expect_true(grepl("REDACTED", paste(output, collapse = "")),
    info = "Redakteret felt skal indeholde REDACTED"
  )
})

test_that("log_warn redakterer token-felt i details", {
  output <- capture.output(
    log_warn(
      "test",
      .context = "TEST",
      details = list(token = "ghp_ABC123", user = "alice")
    )
  )
  combined <- paste(output, collapse = "")
  expect_false(grepl("ghp_ABC123", combined))
  expect_true(grepl("REDACTED", combined))
  # Ikke-hemmelige felter forbliver synlige
  expect_true(grepl("alice", combined))
})

test_that("log_error redakterer password-felt i details", {
  output <- capture.output(
    log_error(
      "test",
      .context = "TEST",
      details = list(password = "hemlig123", reason = "auth_failed")
    )
  )
  combined <- paste(output, collapse = "")
  expect_false(grepl("hemlig123", combined))
  expect_true(grepl("REDACTED", combined))
})

test_that("log_info bevarer ikke-hemmelige felter uændrede", {
  output <- capture.output(
    log_info(
      "test",
      .context = "TEST",
      details = list(rows = 42L, session_id = "abc", chart_type = "run")
    )
  )
  combined <- paste(output, collapse = "")
  expect_true(grepl("42", combined))
  expect_true(grepl("abc", combined))
  expect_true(grepl("run", combined))
  expect_false(grepl("REDACTED", combined))
})
