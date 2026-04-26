# test-app-server-main.R
# Tests for app server og emit API (Phase 5.2, Issue #322)
#
# Fokus: pure-function tests der ikke kræver fuld Shiny session.
# app_server() er en tynd wrapper til main_app_server() — begge kræver session.
# Tests her verificerer hjælpefunktioner og API-strukturer.
#
# NOTE: test-state-management-hierarchical.R dækker allerede create_app_state()
# og event counter increment pattern. Denne fil dækker:
#   - hash_session_token() (security/pure function)
#   - run_app() eksistens
#   - create_emit_api() struktur

# ===========================================================================
# hash_session_token — ren funktion, ingen Shiny krævet
# ===========================================================================

test_that("hash_session_token returnerer 8-tegns hex string", {
  skip_if_not(exists("hash_session_token", mode = "function"))

  result <- hash_session_token("test_token_abc123")

  expect_type(result, "character")
  expect_equal(nchar(result), 8L)
  expect_true(grepl("^[0-9a-f]{8}$", result),
    info = "Skal være 8 hex-tegn (SHA256 prefix)"
  )
})

test_that("hash_session_token er deterministisk for samme input", {
  skip_if_not(exists("hash_session_token", mode = "function"))

  token <- "deterministic_test_token"
  result1 <- hash_session_token(token)
  result2 <- hash_session_token(token)

  expect_identical(result1, result2)
})

test_that("hash_session_token returnerer 'unknown' for NULL og non-character input", {
  skip_if_not(exists("hash_session_token", mode = "function"))

  expect_equal(hash_session_token(NULL), "unknown")
  expect_equal(hash_session_token(123), "unknown")
  expect_equal(hash_session_token(list(a = 1)), "unknown")
})

test_that("hash_session_token producerer unikke hashes for forskellige tokens", {
  skip_if_not(exists("hash_session_token", mode = "function"))

  h1 <- hash_session_token("token_session_A")
  h2 <- hash_session_token("token_session_B")

  expect_false(identical(h1, h2),
    info = "Forskellige tokens skal give forskellige hashes"
  )
})

# ===========================================================================
# app_server og run_app — eksistens og signatur
# ===========================================================================

test_that("app_server eksisterer og er en funktion", {
  expect_true(exists("app_server", mode = "function"))
  expect_type(app_server, "closure")

  # app_server skal tage (input, output, session) — Shiny server-signatur
  formal_names <- names(formals(app_server))
  expect_true("input" %in% formal_names)
  expect_true("output" %in% formal_names)
  expect_true("session" %in% formal_names)
})

test_that("run_app eksisterer og er en funktion", {
  expect_true(exists("run_app", mode = "function"))
  expect_type(run_app, "closure")
})

test_that("main_app_server eksisterer og er en funktion", {
  expect_true(exists("main_app_server", mode = "function"))
  expect_type(main_app_server, "closure")

  formal_names <- names(formals(main_app_server))
  expect_true("input" %in% formal_names)
  expect_true("output" %in% formal_names)
  expect_true("session" %in% formal_names)
})

# ===========================================================================
# create_emit_api — struktur og API
# ===========================================================================

test_that("create_emit_api returnerer en liste med alle forventede emit-funktioner", {
  skip_if_not(exists("create_emit_api", mode = "function"))
  skip_if_not(exists("create_app_state", mode = "function"))

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  expect_type(emit, "list")

  # Verificér at primære emit-funktioner er til stede
  expect_true(is.function(emit$data_updated),
    info = "emit$data_updated skal eksistere"
  )
  expect_true(is.function(emit$auto_detection_started),
    info = "emit$auto_detection_started skal eksistere"
  )
  expect_true(is.function(emit$auto_detection_completed),
    info = "emit$auto_detection_completed skal eksistere"
  )
  expect_true(is.function(emit$ui_sync_requested),
    info = "emit$ui_sync_requested skal eksistere"
  )
})

test_that("emit$data_updated incrementerer event counter", {
  skip_if_not(exists("create_emit_api", mode = "function"))
  skip_if_not(exists("create_app_state", mode = "function"))

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  initial_count <- shiny::isolate(app_state$events$data_updated)
  emit$data_updated("test_context")
  new_count <- shiny::isolate(app_state$events$data_updated)

  expect_equal(new_count, initial_count + 1L)
})

test_that("emit$data_updated saniterer ugyldige context-argumenter", {
  skip_if_not(exists("create_emit_api", mode = "function"))
  skip_if_not(exists("create_app_state", mode = "function"))

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  # Ugyldig context (ikke character) — skal ikke kaste fejl
  expect_no_error(emit$data_updated(NULL))
  expect_no_error(emit$data_updated(123))
  expect_no_error(emit$data_updated(c("a", "b")))

  # Verificér at counteren stadig incrementeres
  count <- shiny::isolate(app_state$events$data_updated)
  expect_gte(count, 3L)
})

test_that("emit$data_updated gemmer context i last_data_update_context", {
  skip_if_not(exists("create_emit_api", mode = "function"))
  skip_if_not(exists("create_app_state", mode = "function"))

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  emit$data_updated("file_upload")

  last_ctx <- app_state$last_data_update_context
  expect_true(!is.null(last_ctx))
  # Context saniteres: kun alfanumerisk + _ og -
  expect_true(grepl("file_upload|file.upload", last_ctx$context))
})
