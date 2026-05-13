# ==============================================================================
# TEST-MOD-LANDING-SERVER.R
# ==============================================================================
# §2.3.3: testServer-kontrakter for mod_landing_server (#230)
#
# Test-fokus:
#   - Auto-restore flow: peek_result styrer landing_body-rendering
#   - Session-state transitions: restore/discard events opdaterer app_state
#
# Modulet har side-effekter (sendCustomMessage, runjs) der ikke kan
# verificeres direkte i testServer. Disse testes kun indirekte via
# observers der opdaterer app_state.
# ==============================================================================

# MOCK HELPERS ================================================================

create_landing_app_state <- function(peek_result = NULL) {
  shiny::reactiveValues(
    session = shiny::reactiveValues(
      peek_result = peek_result
    )
  )
}

# Helper til at udtrække HTML-indhold fra Shiny renderUI-output.
# renderUI returnerer en list med $html (character) og $deps (list).
landing_body_html <- function(out) {
  if (is.null(out)) {
    return("")
  }
  if (is.list(out) && "html" %in% names(out)) {
    return(as.character(out$html))
  }
  as.character(out)
}

# §2.3.3 (landing-render): peek_result styrer landing_body-rendering
# Leveret i §2.3.3 (#230)
test_that("mod_landing_server renders default landing when peek_result is NULL (§2.3.3)", {
  # TEST: Uden gemt session skal landing_body rendere default-landing
  # (kendetegnet ved "start_wizard"-button-id).
  app_state <- create_landing_app_state(peek_result = NULL)

  shiny::testServer(
    mod_landing_server,
    args = list(app_state = app_state, parent_session = NULL),
    {
      rendered <- tryCatch(output$landing_body, error = function(e) NULL)
      expect_true(!is.null(rendered),
        label = "landing_body skal rendere noget (ikke NULL) ved peek_result=NULL"
      )

      html_str <- landing_body_html(rendered)
      expect_true(nchar(html_str) > 0,
        label = "Rendered landing_body skal have indhold"
      )
      # Default landing indeholder "start_wizard"-button-id
      expect_true(grepl("start_wizard", html_str),
        label = "Default landing skal indeholde start_wizard-button"
      )
    }
  )
})

# §2.3.3 (auto-restore flow): peek_result$has_payload=TRUE trigger restore-card
# Leveret i §2.3.3 (#230)
test_that("mod_landing_server renders restore card when saved session available (§2.3.3)", {
  # TEST: peek_result med has_payload=TRUE skal rendere restore-card,
  # som er kendetegnet ved "restore_saved_session"-knap og nrows/ncols-text.
  peek <- list(
    has_payload = TRUE,
    timestamp = "2026-04-19 15:30:00",
    nrows = 42L,
    ncols = 5L
  )
  app_state <- create_landing_app_state(peek_result = peek)

  shiny::testServer(
    mod_landing_server,
    args = list(app_state = app_state, parent_session = NULL),
    {
      session$flushReact()
      rendered <- tryCatch(output$landing_body, error = function(e) NULL)
      expect_true(!is.null(rendered),
        label = "landing_body skal rendere restore-card når peek har payload"
      )

      html_str <- landing_body_html(rendered)
      # Restore-card indeholder "restore_saved_session"-knap + data-beskrivelse
      expect_true(grepl("restore_saved_session", html_str),
        label = "Restore-card skal indeholde restore_saved_session-knap"
      )
      expect_true(grepl("42", html_str),
        label = "Restore-card skal indeholde nrows-værdien (42)"
      )
      expect_true(grepl("kolonner", html_str),
        label = "Restore-card skal indeholde kolonner-tekst"
      )
    }
  )
})

# §2.3.3 (negative path): peek_result$has_payload=FALSE → default landing
# Leveret i §2.3.3 (#230)
test_that("mod_landing_server renders default when no saved payload (§2.3.3)", {
  # TEST: peek_result$has_payload=FALSE (peek afsluttet uden data)
  # skal rendere default-landing (samme som NULL-peek).
  peek <- list(has_payload = FALSE)
  app_state <- create_landing_app_state(peek_result = peek)

  shiny::testServer(
    mod_landing_server,
    args = list(app_state = app_state, parent_session = NULL),
    {
      session$flushReact()
      rendered <- tryCatch(output$landing_body, error = function(e) NULL)
      html_str <- landing_body_html(rendered)

      expect_true(nchar(html_str) > 0,
        label = "landing_body skal rendere indhold ved has_payload=FALSE"
      )
      # Default landing indeholder "start_wizard", IKKE "restore_saved_session"
      expect_true(grepl("start_wizard", html_str),
        label = "Default landing (has_payload=FALSE) skal have start_wizard"
      )
      expect_false(grepl("restore_saved_session", html_str),
        label = "Default landing må IKKE have restore_saved_session"
      )
    }
  )
})

# §2.3.3 (session-state transition): discard_saved_session nulstiller peek_result
# Leveret i §2.3.3 (#230)
test_that("mod_landing_server discard_saved_session updates app_state (§2.3.3)", {
  # TEST: Bruger klikker "Start ny session" → app_state$session$peek_result
  # nulstilles til list(has_payload = FALSE). Verificérer session-state-
  # transition-kontrakten.
  peek <- list(
    has_payload = TRUE,
    timestamp = "2026-04-19 15:30:00",
    nrows = 42L,
    ncols = 5L
  )
  app_state <- create_landing_app_state(peek_result = peek)

  shiny::testServer(
    mod_landing_server,
    args = list(app_state = app_state, parent_session = NULL),
    {
      # Initial: peek_result har payload
      initial_peek <- shiny::isolate(app_state$session$peek_result)
      expect_true(isTRUE(initial_peek$has_payload),
        label = "Initial peek_result skal have payload=TRUE"
      )

      # Trigger discard-event
      session$setInputs(discard_saved_session = 1)
      session$flushReact()

      # Efter discard: peek_result skal være list(has_payload = FALSE)
      after_peek <- shiny::isolate(app_state$session$peek_result)
      expect_type(after_peek, "list")
      expect_false(isTRUE(after_peek$has_payload),
        label = "Efter discard skal peek_result$has_payload være FALSE"
      )
    }
  )
})
