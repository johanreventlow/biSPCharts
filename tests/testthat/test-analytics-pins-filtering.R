# test-analytics-pins-filtering.R
# Tests: filter_shinylogs_allowlist() anvendes på ALLE sync-stier (Phase 1)

# filter_shinylogs_allowlist() returnerer kun tilladte kolonner ================

test_that("filter_shinylogs_allowlist() dropper ikke-tilladte kolonner", {
  skip_if(
    !exists("filter_shinylogs_allowlist",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "filter_shinylogs_allowlist ikke tilgængelig"
  )

  # Opbyg all_data med ekstra farlige kolonner
  all_data <- list(
    sessions = data.frame(
      session_hash = "abc123",
      user = "patient@hospital.dk", # IKKE i allowlist
      browser_connected = "2026-01-01",
      server_connected = "2026-01-01T10:00:00Z",
      server_disconnected = "2026-01-01T10:30:00Z",
      app = "biSPCharts",
      stringsAsFactors = FALSE
    ),
    inputs = data.frame(
      session_hash = "abc123",
      name = "chart_type",
      timestamp = "2026-01-01T10:01:00Z",
      value = "p",
      type = "selectInput", # IKKE i allowlist
      binding = "shiny.select", # IKKE i allowlist
      stringsAsFactors = FALSE
    ),
    outputs = data.frame(
      session_hash = "abc123",
      name = "spc_plot",
      timestamp = "2026-01-01T10:02:00Z",
      stringsAsFactors = FALSE
    ),
    errors = data.frame(
      session_hash = "abc123",
      name = "spc_plot",
      timestamp = "2026-01-01T10:03:00Z",
      redacted_message = "Fejl i plot",
      stringsAsFactors = FALSE
    )
  )

  result <- biSPCharts:::filter_shinylogs_allowlist(all_data)

  # user og browser_connected må IKKE være med
  expect_false("user" %in% names(result$sessions))
  expect_false("browser_connected" %in% names(result$sessions))

  # type og binding må IKKE være med
  expect_false("type" %in% names(result$inputs))
  expect_false("binding" %in% names(result$inputs))

  # Tilladte kolonner skal bevares
  expect_true("session_hash" %in% names(result$sessions))
  expect_true("server_connected" %in% names(result$sessions))
  expect_true("name" %in% names(result$inputs))
})

test_that("filter_shinylogs_allowlist() bevarer session_hash i alle tabeller", {
  skip_if(
    !exists("filter_shinylogs_allowlist",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "filter_shinylogs_allowlist ikke tilgængelig"
  )

  all_data <- list(
    sessions = data.frame(
      session_hash = "hash1", app = "biSPCharts",
      server_connected = "2026-01-01", server_disconnected = "2026-01-01",
      stringsAsFactors = FALSE
    ),
    inputs = data.frame(
      session_hash = "hash1", name = "x", timestamp = "t",
      value = "v", stringsAsFactors = FALSE
    ),
    outputs = data.frame(
      session_hash = "hash1", name = "y", timestamp = "t",
      stringsAsFactors = FALSE
    ),
    errors = data.frame(
      session_hash = "hash1", name = "z", timestamp = "t",
      redacted_message = "ok", stringsAsFactors = FALSE
    )
  )

  result <- biSPCharts:::filter_shinylogs_allowlist(all_data)

  expect_true("session_hash" %in% names(result$sessions))
  expect_true("session_hash" %in% names(result$inputs))
  expect_true("session_hash" %in% names(result$outputs))
  expect_true("session_hash" %in% names(result$errors))
})
