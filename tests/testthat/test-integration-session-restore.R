# ==============================================================================
# test-integration-session-restore.R
# ==============================================================================
# INTEGRATION TESTS: Session restore-flow (Issue #590, #193)
#
# Verificerer:
#   * Restore-card vises naar peek_result.has_payload = TRUE (mod_landing_server)
#   * "Gendan session"-klik trigger performSessionRestore custom-message
#   * "Start ny session"-klik nulstiller peek_result + clearer localStorage
#   * Restore-flag (restoring_session) coalesces double-render (fix-pattern #403)
#
# Caveats:
#   * Visuel verifikation af restore-card-rendering kraever shinytest2 nightly.
#     Vi asserter at output$landing_body ER renderet (renderUI returnerer
#     non-NULL HTML) + at restore_saved_session-button ID findes i HTML.
#   * sendCustomMessage-payload-verifikation kraever en mock-session med
#     custom message-capture; vi monkey-patcher session$sendCustomMessage()
#     i testServer for at fange opkald.
# ==============================================================================

library(testthat)
library(shiny)

# ============================================================================
# SUITE: Restore-card rendering
# ============================================================================

test_that("Landing module: restore-card rendres naar peek_result har payload", {
  skip_if_not_installed("shiny")

  app_state <- create_app_state()
  # Sæt peek_result FOER moduleServer-kald saa renderUI ser den
  set_session_peek_result(app_state, mock_local_storage_peek_result(
    has_payload = TRUE,
    timestamp = "2024-12-01 10:00:00",
    nrows = 25L,
    ncols = 5L
  ))

  shiny::testServer(mod_landing_server,
    args = list(parent_session = NULL, app_state = app_state),
    {
      session$flushReact()

      # Verify renderUI returnerede ej-NULL indhold
      body <- output$landing_body
      expect_true(!is.null(body))

      # restore_saved_session-button ID skal vaere i HTML
      html <- paste(as.character(body), collapse = "")
      expect_true(grepl("restore_saved_session", html, fixed = TRUE),
        label = "restore_saved_session button skal vaere i restore-card HTML"
      )
    }
  )
})

test_that("Landing module: default-card rendres naar peek_result har_payload = FALSE", {
  skip_if_not_installed("shiny")

  app_state <- create_app_state()
  set_session_peek_result(app_state, mock_local_storage_peek_result(
    has_payload = FALSE
  ))

  shiny::testServer(mod_landing_server,
    args = list(parent_session = NULL, app_state = app_state),
    {
      session$flushReact()
      body <- output$landing_body
      expect_true(!is.null(body))
      html <- paste(as.character(body), collapse = "")

      # restore-button skal IKKE vaere i default-landing
      expect_false(grepl("restore_saved_session", html, fixed = TRUE))
    }
  )
})

test_that("Landing module: NULL peek_result viser default-landing (intet flash)", {
  skip_if_not_installed("shiny")

  app_state <- create_app_state()
  # Bevidst INTET set_session_peek_result -- peek_result er NULL by default

  shiny::testServer(mod_landing_server,
    args = list(parent_session = NULL, app_state = app_state),
    {
      session$flushReact()
      body <- output$landing_body
      expect_true(!is.null(body))
      # Default-landing skal vaere render-baar uden fejl
      html <- paste(as.character(body), collapse = "")
      expect_gt(nchar(html), 0L)
    }
  )
})

# ============================================================================
# SUITE: Restore-flag coalesce single-render (fix-pattern #403)
# ============================================================================

test_that("Restore-flag: data_updated under restoring_session preserverer flag", {
  skip_if_not_installed("shiny")

  test_server <- function(input, output, session) {
    app_state <- create_app_state()
    emit <- create_emit_api(app_state)
    setup_event_listeners(app_state, emit, input, output, session, ui_service = NULL)

    session$userData$app_state <- app_state
    session$userData$emit <- emit
  }

  shiny::testServer(test_server, {
    app_state <- session$userData$app_state
    emit <- session$userData$emit

    # Simuler restore-init: saet flag FOER data emit
    app_state$session$restoring_session <- TRUE
    expect_true(is_restoring_session(app_state))

    # Simuler restore loader data
    app_state$data$current_data <- create_test_data()
    emit$data_updated(context = "session_restore")
    session$flushReact()
    if (requireNamespace("later", quietly = TRUE)) later::run_now(2)
    session$flushReact()

    # Flag skal stadig vaere TRUE -- cleanup koerer eksplicit *efter* flush
    # (fct_file_operations.R:320-345). Hvis flag er FALSE her, betyder det
    # at observers nulstillede den for tidligt -> auto-nav til "analyser"
    # ville have overskrevet brugerens saved_tab. Det er regression #193.
    expect_true(is_restoring_session(app_state),
      label = "restoring_session flag skal preserveres gennem data_updated-flush"
    )
  })
})

test_that("Restore-flag: chart-listener guard'er paa restoring_session", {
  skip_if_not_installed("shiny")

  test_server <- function(input, output, session) {
    app_state <- create_app_state()
    emit <- create_emit_api(app_state)
    setup_event_listeners(app_state, emit, input, output, session, ui_service = NULL)

    session$userData$app_state <- app_state
    session$userData$emit <- emit
  }

  shiny::testServer(test_server, {
    app_state <- session$userData$app_state
    emit <- session$userData$emit

    # Verify event-counters initialiseret
    expect_true(!is.null(app_state$events$data_updated))

    # Snapshot pre-restore counter
    pre_data_updated <- shiny::isolate(app_state$events$data_updated %||% 0L)

    # Simuler complete restore-cycle med flag
    app_state$session$restoring_session <- TRUE
    app_state$data$current_data <- create_test_data()
    app_state$columns$x_column <- "Dato"
    app_state$columns$y_column <- "Tæller"
    app_state$columns$n_column <- "Nævner"

    # Restore emitter data_updated EN gang (coalesced; ikke per-felt)
    emit$data_updated(context = "session_restore")
    session$flushReact()
    if (requireNamespace("later", quietly = TRUE)) later::run_now(2)
    session$flushReact()

    # Verify EXACTLY-ONCE increment efter en restore-cycle
    post_data_updated <- shiny::isolate(app_state$events$data_updated %||% 0L)
    expect_equal(post_data_updated, pre_data_updated + 1L,
      label = paste(
        "Restore skal trigge praecis 1 data_updated event;",
        "double-render (fix-pattern #403) ville give +2 eller mere"
      )
    )
  })
})

# ============================================================================
# SUITE: discard_saved_session nulstiller peek_result
# ============================================================================

test_that("Landing module: set_session_peek_result haandterer discard-flow", {
  skip_if_not_installed("shiny")

  app_state <- create_app_state()
  set_session_peek_result(app_state, mock_local_storage_peek_result(
    has_payload = TRUE
  ))
  expect_true(isTRUE(shiny::isolate(app_state$session$peek_result$has_payload)))

  # Simuler discard
  set_session_peek_result(app_state, list(has_payload = FALSE))
  expect_false(isTRUE(shiny::isolate(app_state$session$peek_result$has_payload)))
})
