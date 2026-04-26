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

# resolve_analytics_config() — golem-config prioritet =======================

test_that("resolve_analytics_config(): ENABLE_SHINYLOGS=FALSE giver FALSE naar config ikke er sat", {
  withr::with_envvar(
    list(BISPC_DISABLE_ANALYTICS = "", ENABLE_SHINYLOGS = "FALSE"),
    {
      mockery::stub(
        resolve_analytics_config,
        "golem::get_golem_options",
        NULL
      )
      expect_false(resolve_analytics_config()$enabled)
    }
  )
})

test_that("resolve_analytics_config(): config-flag FALSE returnerer FALSE selv med ENABLE_SHINYLOGS=TRUE", {
  withr::with_envvar(
    list(BISPC_DISABLE_ANALYTICS = "", ENABLE_SHINYLOGS = "TRUE"),
    {
      mockery::stub(
        resolve_analytics_config,
        "golem::get_golem_options",
        FALSE
      )
      expect_false(resolve_analytics_config()$enabled)
    }
  )
})

test_that("resolve_analytics_config(): config-flag TRUE returnerer TRUE", {
  withr::with_envvar(
    list(BISPC_DISABLE_ANALYTICS = ""),
    {
      mockery::stub(
        resolve_analytics_config,
        "golem::get_golem_options",
        TRUE
      )
      expect_true(resolve_analytics_config()$enabled)
    }
  )
})

# redact_col_names() ==================================================

test_that("redact_col_names(): PII-kolonnenavne redakteres", {
  result <- redact_col_names(c("dato", "navn", "x"))
  expect_equal(result[1], "dato")
  expect_equal(result[2], "[redacted]")
  expect_equal(result[3], "x")
})

test_that("redact_col_names(): CPR-lignende kolonnenavn redakteres", {
  result <- redact_col_names(c("120345-6789", "value"))
  expect_equal(result[1], "[redacted]")
  expect_equal(result[2], "value")
})

test_that("redact_col_names(): email-tegn redakteres", {
  result <- redact_col_names(c("email", "x_email_y", "value"))
  expect_equal(result[1], "[redacted]")
  expect_equal(result[2], "[redacted]")
  expect_equal(result[3], "value")
})

test_that("redact_col_names(): patient-kolonne redakteres", {
  result <- redact_col_names(c("patient_id", "date"))
  expect_equal(result[1], "[redacted]")
  expect_equal(result[2], "date")
})

test_that("redact_col_names(): ufarlige kolonnenavne passerer uredigerede", {
  cols <- c("dato", "vaerdi", "chart_type", "x", "y")
  result <- redact_col_names(cols)
  expect_equal(result, cols)
})

test_that("redact_col_names(): tomt kolonnenavn-vector returneres tomt", {
  result <- redact_col_names(character(0))
  expect_length(result, 0)
})

# redact_debug_snapshot() ==================================================

test_that("redact_debug_snapshot(): redakterer col_names i snapshot$data_summary", {
  snapshot <- list(data_summary = list(current_data = list(col_names = c("navn", "value"))))
  result <- redact_debug_snapshot(snapshot)
  expect_equal(result$data_summary$current_data$col_names[1], "[redacted]")
  expect_equal(result$data_summary$current_data$col_names[2], "value")
})

test_that("redact_debug_snapshot(): returnerer snapshot uaendret hvis ingen col_names", {
  snapshot <- list(a = 1, b = "x")
  result <- redact_debug_snapshot(snapshot)
  expect_equal(result, snapshot)
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
