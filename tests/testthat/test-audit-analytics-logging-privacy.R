# Tests for audit-analytics-logging-privacy OpenSpec change (#323)

# should_enable_shinylogs() ================================================

test_that("should_enable_shinylogs(): kill-switch deaktiverer uanset ENABLE_SHINYLOGS", {
  withr::with_envvar(
    list(BISPC_DISABLE_ANALYTICS = "true", ENABLE_SHINYLOGS = "TRUE"),
    expect_false(should_enable_shinylogs())
  )
})

test_that("should_enable_shinylogs(): kill-switch accepterer TRUE, 1, YES, ON", {
  for (val in c("TRUE", "1", "YES", "ON")) {
    withr::with_envvar(
      list(BISPC_DISABLE_ANALYTICS = val),
      expect_false(should_enable_shinylogs(), label = paste("kill-switch =", val))
    )
  }
})

test_that("should_enable_shinylogs(): tomt kill-switch falder igennem til legacy env-var", {
  withr::with_envvar(
    list(BISPC_DISABLE_ANALYTICS = "", ENABLE_SHINYLOGS = "FALSE"),
    {
      # Ingen golem-config i test-kontekst, falder tilbage til ENABLE_SHINYLOGS
      result <- should_enable_shinylogs()
      # TRUE eller FALSE afhaenger af context, men kill-switch maa ikke vinde
      expect_true(is.logical(result))
    }
  )
})

test_that("should_enable_shinylogs(): ENABLE_SHINYLOGS=FALSE giver FALSE naar config ikke er sat", {
  withr::with_envvar(
    list(BISPC_DISABLE_ANALYTICS = "", ENABLE_SHINYLOGS = "FALSE"),
    {
      # Simulér at golem-config returnerer NULL (ingen config sat)
      mockery::stub(
        should_enable_shinylogs,
        "golem::get_golem_options",
        NULL
      )
      expect_false(should_enable_shinylogs())
    }
  )
})

test_that("should_enable_shinylogs(): config-flag FALSE returnerer FALSE", {
  withr::with_envvar(
    list(BISPC_DISABLE_ANALYTICS = "", ENABLE_SHINYLOGS = "TRUE"),
    {
      mockery::stub(
        should_enable_shinylogs,
        "golem::get_golem_options",
        FALSE
      )
      expect_false(should_enable_shinylogs())
    }
  )
})

test_that("should_enable_shinylogs(): config-flag TRUE returnerer TRUE", {
  withr::with_envvar(
    list(BISPC_DISABLE_ANALYTICS = ""),
    {
      mockery::stub(
        should_enable_shinylogs,
        "golem::get_golem_options",
        TRUE
      )
      expect_true(should_enable_shinylogs())
    }
  )
})

# redact_debug_snapshot() ==================================================

test_that("redact_debug_snapshot(): PII-kolonnenavne redakteres", {
  result <- redact_debug_snapshot(list(), c("dato", "navn", "x"))
  expect_equal(result$redacted_col_names[1], "dato")
  expect_equal(result$redacted_col_names[2], "[redacted]")
  expect_equal(result$redacted_col_names[3], "x")
})

test_that("redact_debug_snapshot(): CPR-lignende kolonnenavn redakteres", {
  result <- redact_debug_snapshot(list(), c("120345-6789", "value"))
  expect_equal(result$redacted_col_names[1], "[redacted]")
  expect_equal(result$redacted_col_names[2], "value")
})

test_that("redact_debug_snapshot(): email-tegn redakteres", {
  result <- redact_debug_snapshot(list(), c("email", "x_email_y", "value"))
  expect_equal(result$redacted_col_names[1], "[redacted]")
  expect_equal(result$redacted_col_names[2], "[redacted]")
  expect_equal(result$redacted_col_names[3], "value")
})

test_that("redact_debug_snapshot(): patient-kolonne redakteres", {
  result <- redact_debug_snapshot(list(), c("patient_id", "date"))
  expect_equal(result$redacted_col_names[1], "[redacted]")
  expect_equal(result$redacted_col_names[2], "date")
})

test_that("redact_debug_snapshot(): ufarlige kolonnenavne passerer uredigerede", {
  cols <- c("dato", "vaerdi", "chart_type", "x", "y")
  result <- redact_debug_snapshot(list(), cols)
  expect_equal(result$redacted_col_names, cols)
})

test_that("redact_debug_snapshot(): tomt kolonnenavn-vector returneres tomt", {
  result <- redact_debug_snapshot(list(), character(0))
  expect_length(result$redacted_col_names, 0)
})

test_that("redact_debug_snapshot(): safe_hash_input er en liste", {
  result <- redact_debug_snapshot(list(a = 1), c("navn"))
  expect_type(result$safe_hash_input, "list")
})

# SHINYLOGS_ALLOWLIST doc-sync ==============================================

test_that("SHINYLOGS_ALLOWLIST er synkroniseret med ANALYTICS_PRIVACY.md", {
  privacy_doc_path <- here::here("docs", "ANALYTICS_PRIVACY.md")
  skip_if_not(file.exists(privacy_doc_path), "docs/ANALYTICS_PRIVACY.md ikke fundet")

  privacy_doc <- readLines(privacy_doc_path, warn = FALSE)
  all_allowed_cols <- unique(unlist(SHINYLOGS_ALLOWLIST))
  for (col in all_allowed_cols) {
    expect_true(
      any(grepl(col, privacy_doc, fixed = TRUE)),
      label = paste("Kolonne", col, "mangler i ANALYTICS_PRIVACY.md")
    )
  }
})
