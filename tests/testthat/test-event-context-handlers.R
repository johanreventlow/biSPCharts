# ==============================================================================
# test-event-context-handlers.R
# ==============================================================================
# §2.2.3 — Unit-tests for ekstraherede event context handlers i
# R/utils_event_context_handlers.R.
#
# Phase 2d-refactoring ekstraherede strategy-pattern-handlers for data_updated-
# events. Disse er pure funktioner (bortset fra side-effects via emit), så de
# kan testes direkte uden testServer.
#
# Test-fokus:
#   - classify_update_context: context-string → handler-type routing
#   - handle_load_context: triggerer auto_detection_started kun ved data
#   - handle_table_edit_context: navigation + visualization (ingen auto-detect)
#   - handle_data_change_context: column choices + navigation + viz
#   - handle_general_context: kun column choices (konservativ fallback)
#   - handle_session_restore_context: choices + navigation + viz (no autodetect)
#   - handle_data_update_by_context: dispatcher routing
#
# Pattern: mock emit-list med spy-funktioner der optæller kald.
# ==============================================================================

# ------------------------------------------------------------------------------
# Mock-helpers
# ------------------------------------------------------------------------------

#' Create spy-emit API der optæller kald til hvert event
create_spy_emit <- function() {
  counts <- new.env(parent = emptyenv())
  counts$auto_detection_started <- 0L
  counts$navigation_changed <- 0L
  counts$visualization_update_needed <- 0L
  counts$data_updated <- 0L

  emit <- list(
    auto_detection_started = function() {
      counts$auto_detection_started <- counts$auto_detection_started + 1L
    },
    navigation_changed = function() {
      counts$navigation_changed <- counts$navigation_changed + 1L
    },
    visualization_update_needed = function() {
      counts$visualization_update_needed <- counts$visualization_update_needed + 1L
    },
    data_updated = function(context = NULL, ...) {
      counts$data_updated <- counts$data_updated + 1L
    }
  )

  list(emit = emit, counts = counts)
}

#' Create minimal app_state med data.current_data felt
create_handler_app_state <- function(has_data = TRUE) {
  state <- new.env(parent = emptyenv())
  state$data <- new.env(parent = emptyenv())
  state$data$current_data <- if (has_data) {
    data.frame(x = 1:10, y = rnorm(10))
  } else {
    NULL
  }
  state
}

# ============================================================================
# classify_update_context
# ============================================================================

test_that("classify_update_context returnerer 'general' ved NULL input (§2.2.3)", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  expect_equal(classify_update_context(NULL), "general")
  expect_equal(classify_update_context(list()), "general")
  expect_equal(classify_update_context(list(context = NULL)), "general")
})

test_that("classify_update_context identificerer 'load' ved upload-kontekster (§2.2.3)", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  expect_equal(classify_update_context(list(context = "file_upload")), "load")
  expect_equal(classify_update_context(list(context = "data_loaded")), "load")
  expect_equal(classify_update_context(list(context = "new_file")), "load")
  expect_equal(classify_update_context(list(context = "paste_data")), "load")
})

test_that("classify_update_context identificerer 'table_edit' exakt (§2.2.3)", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  # Kun exact match — skal ikke matche andre "edit"-varianter
  expect_equal(
    classify_update_context(list(context = "table_cells_edited")),
    "table_edit"
  )
  # Andre edit-strings falder til data_change (grepl matcher 'edit')
  expect_equal(
    classify_update_context(list(context = "cell_edit")),
    "data_change"
  )
})

test_that("classify_update_context identificerer 'session_restore' exakt (§2.2.3)", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  expect_equal(
    classify_update_context(list(context = "session_restore")),
    "session_restore"
  )
  # "session" alene falder til general (match kræver exact "session_restore")
  expect_equal(
    classify_update_context(list(context = "session")),
    "general"
  )
})

test_that("classify_update_context identificerer 'data_change' ved edit/modify (§2.2.3)", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  expect_equal(
    classify_update_context(list(context = "data_change")),
    "data_change"
  )
  expect_equal(
    classify_update_context(list(context = "column_modify")),
    "data_change"
  )
  expect_equal(
    classify_update_context(list(context = "user_edit")),
    "data_change"
  )
})

test_that("classify_update_context falder tilbage til 'general' for ukendte (§2.2.3)", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  expect_equal(
    classify_update_context(list(context = "something_random")),
    "general"
  )
  expect_equal(classify_update_context(list(context = "")), "general")
})

# ============================================================================
# handle_load_context
# ============================================================================

test_that("handle_load_context triggerer auto-detection når data findes (§2.2.3)", {
  skip_if_not(exists("handle_load_context", mode = "function"))

  spy <- create_spy_emit()
  app_state <- create_handler_app_state(has_data = TRUE)

  expect_no_error(handle_load_context(app_state, spy$emit))

  expect_equal(spy$counts$auto_detection_started, 1L,
    label = "auto_detection_started skal kaldes præcis én gang ved data"
  )
  expect_equal(spy$counts$navigation_changed, 0L)
  expect_equal(spy$counts$visualization_update_needed, 0L)
})

test_that("handle_load_context springer auto-detection over uden data (§2.2.3)", {
  skip_if_not(exists("handle_load_context", mode = "function"))

  spy <- create_spy_emit()
  app_state <- create_handler_app_state(has_data = FALSE)

  expect_no_error(handle_load_context(app_state, spy$emit))

  expect_equal(spy$counts$auto_detection_started, 0L,
    label = "auto_detection_started må IKKE kaldes uden data"
  )
})

# ============================================================================
# handle_table_edit_context
# ============================================================================

test_that("handle_table_edit_context triggerer navigation+viz (§2.2.3)", {
  skip_if_not(exists("handle_table_edit_context", mode = "function"))

  spy <- create_spy_emit()
  app_state <- create_handler_app_state(has_data = TRUE)

  expect_no_error(handle_table_edit_context(app_state, spy$emit))

  # Skal kalde navigation_changed og visualization_update_needed
  expect_equal(spy$counts$navigation_changed, 1L)
  expect_equal(spy$counts$visualization_update_needed, 1L)

  # Må IKKE trigger auto-detection (bevar user's column mappings)
  expect_equal(spy$counts$auto_detection_started, 0L,
    label = "Table edit må IKKE trigger auto-detection"
  )
})

# ============================================================================
# handle_data_change_context
# ============================================================================

test_that("handle_data_change_context triggerer choices+navigation+viz (§2.2.3)", {
  skip_if_not(exists("handle_data_change_context", mode = "function"))

  spy <- create_spy_emit()
  app_state <- create_handler_app_state(has_data = TRUE)

  # Mock update_column_choices_unified så vi ikke kræver fuld UI-context
  choices_call_count <- 0L
  testthat::local_mocked_bindings(
    update_column_choices_unified = function(...) {
      choices_call_count <<- choices_call_count + 1L
      invisible(NULL)
    }
  )

  expect_no_error(
    handle_data_change_context(
      app_state = app_state,
      emit = spy$emit,
      input = list(),
      output = list(),
      session = NULL,
      ui_service = NULL,
      context = "column_change"
    )
  )

  expect_equal(choices_call_count, 1L,
    label = "update_column_choices_unified skal kaldes én gang"
  )
  expect_equal(spy$counts$navigation_changed, 1L)
  expect_equal(spy$counts$visualization_update_needed, 1L)
  expect_equal(spy$counts$auto_detection_started, 0L,
    label = "data_change må IKKE trigger auto-detection"
  )
})

# ============================================================================
# handle_general_context
# ============================================================================

test_that("handle_general_context triggerer kun choices (ingen navigation/viz) (§2.2.3)", {
  skip_if_not(exists("handle_general_context", mode = "function"))

  spy <- create_spy_emit()
  app_state <- create_handler_app_state(has_data = TRUE)

  choices_call_count <- 0L
  testthat::local_mocked_bindings(
    update_column_choices_unified = function(...) {
      choices_call_count <<- choices_call_count + 1L
      invisible(NULL)
    }
  )

  expect_no_error(
    handle_general_context(
      app_state = app_state,
      emit = spy$emit,
      input = list(),
      output = list(),
      session = NULL,
      ui_service = NULL,
      context = "unknown"
    )
  )

  expect_equal(choices_call_count, 1L)
  # Konservativ fallback — ingen plots eller auto-detect
  expect_equal(spy$counts$navigation_changed, 0L)
  expect_equal(spy$counts$visualization_update_needed, 0L)
  expect_equal(spy$counts$auto_detection_started, 0L)
})

# ============================================================================
# handle_session_restore_context
# ============================================================================

test_that("handle_session_restore_context triggerer choices+navigation+viz (§2.2.3)", {
  skip_if_not(exists("handle_session_restore_context", mode = "function"))

  spy <- create_spy_emit()
  app_state <- create_handler_app_state(has_data = TRUE)

  choices_reason <- NULL
  testthat::local_mocked_bindings(
    update_column_choices_unified = function(app_state, input, output, session,
                                             ui_service, reason = NULL) {
      choices_reason <<- reason
      invisible(NULL)
    }
  )

  expect_no_error(
    handle_session_restore_context(
      app_state = app_state,
      emit = spy$emit,
      input = list(),
      output = list(),
      session = NULL,
      ui_service = NULL
    )
  )

  # Session restore bruger reason="session" til update_column_choices
  expect_equal(choices_reason, "session")
  expect_equal(spy$counts$navigation_changed, 1L)
  expect_equal(spy$counts$visualization_update_needed, 1L)
  # Må IKKE trigger auto-detection — vi har gemte mappings
  expect_equal(spy$counts$auto_detection_started, 0L,
    label = "session_restore må IKKE trigger auto-detection"
  )
})

# ============================================================================
# handle_data_update_by_context (dispatcher)
# ============================================================================

test_that("handle_data_update_by_context dispatcher ruter 'load' korrekt (§2.2.3)", {
  skip_if_not(exists("handle_data_update_by_context", mode = "function"))

  spy <- create_spy_emit()
  app_state <- create_handler_app_state(has_data = TRUE)

  expect_no_error(
    handle_data_update_by_context(
      update_context = list(context = "file_upload"),
      app_state = app_state,
      emit = spy$emit,
      input = list(),
      output = list(),
      session = NULL,
      ui_service = NULL
    )
  )

  # Load-context router til handle_load_context → auto_detection_started
  expect_equal(spy$counts$auto_detection_started, 1L)
  # IKKE navigation/viz (kommer via auto_detection_completed senere)
  expect_equal(spy$counts$navigation_changed, 0L)
  expect_equal(spy$counts$visualization_update_needed, 0L)
})

test_that("handle_data_update_by_context dispatcher ruter 'table_edit' korrekt (§2.2.3)", {
  skip_if_not(exists("handle_data_update_by_context", mode = "function"))

  spy <- create_spy_emit()
  app_state <- create_handler_app_state(has_data = TRUE)

  expect_no_error(
    handle_data_update_by_context(
      update_context = list(context = "table_cells_edited"),
      app_state = app_state,
      emit = spy$emit,
      input = list(),
      output = list(),
      session = NULL,
      ui_service = NULL
    )
  )

  # Table edit → navigation + viz (ikke autodetect)
  expect_equal(spy$counts$navigation_changed, 1L)
  expect_equal(spy$counts$visualization_update_needed, 1L)
  expect_equal(spy$counts$auto_detection_started, 0L)
})

test_that("handle_data_update_by_context dispatcher ruter 'session_restore' korrekt (§2.2.3)", {
  skip_if_not(exists("handle_data_update_by_context", mode = "function"))

  spy <- create_spy_emit()
  app_state <- create_handler_app_state(has_data = TRUE)

  testthat::local_mocked_bindings(
    update_column_choices_unified = function(...) invisible(NULL)
  )

  expect_no_error(
    handle_data_update_by_context(
      update_context = list(context = "session_restore"),
      app_state = app_state,
      emit = spy$emit,
      input = list(),
      output = list(),
      session = NULL,
      ui_service = NULL
    )
  )

  expect_equal(spy$counts$navigation_changed, 1L)
  expect_equal(spy$counts$visualization_update_needed, 1L)
  expect_equal(spy$counts$auto_detection_started, 0L,
    label = "session_restore må aldrig trigger auto-detection"
  )
})

test_that("handle_data_update_by_context dispatcher fallback til 'general' (§2.2.3)", {
  skip_if_not(exists("handle_data_update_by_context", mode = "function"))

  spy <- create_spy_emit()
  app_state <- create_handler_app_state(has_data = TRUE)

  choices_call_count <- 0L
  testthat::local_mocked_bindings(
    update_column_choices_unified = function(...) {
      choices_call_count <<- choices_call_count + 1L
      invisible(NULL)
    }
  )

  # NULL update_context → general handler
  expect_no_error(
    handle_data_update_by_context(
      update_context = NULL,
      app_state = app_state,
      emit = spy$emit,
      input = list(),
      output = list(),
      session = NULL,
      ui_service = NULL
    )
  )

  expect_equal(choices_call_count, 1L,
    label = "general handler skal kalde update_column_choices"
  )
  # Ingen plot/nav/autodetect
  expect_equal(spy$counts$navigation_changed, 0L)
  expect_equal(spy$counts$visualization_update_needed, 0L)
  expect_equal(spy$counts$auto_detection_started, 0L)
})

# ============================================================================
# Defensive: alle handlers kaster ikke fejl ved manglende app_state-felter
# ============================================================================

test_that("handle_load_context håndterer manglende data-felt defensivt (§2.2.3)", {
  skip_if_not(exists("handle_load_context", mode = "function"))

  spy <- create_spy_emit()
  # app_state uden data-felt
  app_state <- new.env(parent = emptyenv())
  app_state$data <- new.env(parent = emptyenv())
  # current_data findes ikke

  expect_no_error(handle_load_context(app_state, spy$emit))
  expect_equal(spy$counts$auto_detection_started, 0L)
})
