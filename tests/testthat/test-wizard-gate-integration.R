# ==============================================================================
# test-wizard-gate-integration.R
# ==============================================================================
# INTEGRATION TESTS: Wizard navigation-gates (Issue #590)
#
# Verificerer at:
#   * Initial setup laaser trin 2 + 3 via sendCustomMessage("wizard-lock-step")
#   * data_updated med data => wizard-complete-step 1 + wizard-unlock-step 2
#   * data_updated UDEN data => wizard-lock-step 2 + 3
#   * plot_ready = TRUE => wizard-unlock-step 3 + wizard-complete-step 2
#   * plot_ready = FALSE => wizard-lock-step 3 + wizard-uncomplete-step 2
#   * Auto-nav til "analyser" SKIPPES under restoring_session = TRUE (#193)
# ==============================================================================

library(testthat)
library(shiny)

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

# Robust serialiser: tager (type, message) -> "type:message" hvor message er
# skalar eller list. Filtreres saa kun simple integer/character-messages
# bruges i assertions (wizard-flow har skalar message-payload).
fmt_msg <- function(m) {
  msg <- m$message
  msg_str <- if (is.atomic(msg) && length(msg) == 1L) {
    as.character(msg)
  } else {
    paste(deparse(msg), collapse = "")
  }
  paste0(m$type, ":", msg_str)
}

# Capture-harness: returnerer et test_server suitable til shiny::testServer.
# Setup_wizard_gates kalder bslib::nav_select og shinyjs::enable/disable —
# disse stubbes via testthat::with_mocked_bindings paa TEST-niveau (ej i
# server-funktionen), ellers er mockene ej aktive naar observers fyrer.
make_wizard_test_harness <- function() {
  function(input, output, session) {
    app_state <- create_app_state()

    # Capture sendCustomMessage opkald
    custom_messages <- list()
    session$sendCustomMessage <- function(type, message) {
      custom_messages[[length(custom_messages) + 1L]] <<- list(
        type = type, message = message
      )
      invisible(NULL)
    }

    # Eksponer state + capture-buffer
    session$userData$app_state <- app_state
    session$userData$custom_messages <- function() custom_messages

    # Registrér wizard-gates (det er det vi tester)
    setup_wizard_gates(input, output, app_state, session)
  }
}

# ----------------------------------------------------------------------------
# Mocks bruges paa test-niveau via with_mocked_bindings(). Vi tracker nav-calls
# globalt i en counter-environment for at minimize boilerplate.
# ----------------------------------------------------------------------------

new_call_tracker <- function() {
  e <- new.env(parent = emptyenv())
  e$nav <- list()
  e$js <- list()
  e
}

mock_nav_select_fn <- function(tracker) {
  function(id, selected = NULL, session = NULL, ...) {
    tracker$nav[[length(tracker$nav) + 1L]] <- list(id = id, selected = selected)
    invisible(NULL)
  }
}

mock_shinyjs_fn <- function(tracker, action) {
  function(id, ...) {
    tracker$js[[length(tracker$js) + 1L]] <- list(action = action, id = id)
    invisible(NULL)
  }
}

# ============================================================================
# SUITE: Initial gate-state ved setup
# ============================================================================

test_that("setup_wizard_gates: initial laasning af trin 2 + 3", {
  skip_if_not_installed("shiny")
  tracker <- new_call_tracker()

  testthat::with_mocked_bindings(
    nav_select = mock_nav_select_fn(tracker),
    .package = "bslib",
    {
      testthat::with_mocked_bindings(
        enable = mock_shinyjs_fn(tracker, "enable"),
        disable = mock_shinyjs_fn(tracker, "disable"),
        .package = "shinyjs",
        {
          shiny::testServer(make_wizard_test_harness(), {
            session$flushReact()
            msgs <- session$userData$custom_messages()
            ids <- vapply(msgs, fmt_msg, character(1))

            expect_true("wizard-lock-step:2" %in% ids)
            expect_true("wizard-lock-step:3" %in% ids)
          })
        }
      )
    }
  )
})

# ============================================================================
# SUITE: data_updated unlocks trin 2 naar data findes
# ============================================================================

test_that("Wizard-gate: data_updated MED data unlocker trin 2 + completer trin 1", {
  skip_if_not_installed("shiny")
  tracker <- new_call_tracker()

  testthat::with_mocked_bindings(
    nav_select = mock_nav_select_fn(tracker),
    .package = "bslib",
    {
      testthat::with_mocked_bindings(
        enable = mock_shinyjs_fn(tracker, "enable"),
        disable = mock_shinyjs_fn(tracker, "disable"),
        .package = "shinyjs",
        {
          shiny::testServer(make_wizard_test_harness(), {
            app_state <- session$userData$app_state
            session$flushReact()
            init_count <- length(session$userData$custom_messages())

            app_state$data$current_data <- create_test_data()
            app_state$events$data_updated <- (app_state$events$data_updated %||% 0L) + 1L
            session$flushReact()

            msgs <- session$userData$custom_messages()
            new_msgs <- msgs[seq.int(init_count + 1L, length(msgs))]
            ids <- vapply(new_msgs, fmt_msg, character(1))

            expect_true("wizard-complete-step:1" %in% ids,
              label = "Trin 1 skal completes naar data uploadet"
            )
            expect_true("wizard-unlock-step:2" %in% ids,
              label = "Trin 2 skal unlockes naar data uploadet"
            )
          })
        }
      )
    }
  )
})

test_that("Wizard-gate: auto-nav til 'analyser' SKIPPES under restoring_session", {
  skip_if_not_installed("shiny")
  tracker <- new_call_tracker()

  testthat::with_mocked_bindings(
    nav_select = mock_nav_select_fn(tracker),
    .package = "bslib",
    {
      testthat::with_mocked_bindings(
        enable = mock_shinyjs_fn(tracker, "enable"),
        disable = mock_shinyjs_fn(tracker, "disable"),
        .package = "shinyjs",
        {
          shiny::testServer(make_wizard_test_harness(), {
            app_state <- session$userData$app_state
            app_state$session$restoring_session <- TRUE

            session$flushReact()

            app_state$data$current_data <- create_test_data()
            app_state$events$data_updated <- (app_state$events$data_updated %||% 0L) + 1L
            session$flushReact()

            analyser_calls <- Filter(
              function(c) identical(c$selected, "analyser"),
              tracker$nav
            )
            expect_length(analyser_calls, 0L)
          })
        }
      )
    }
  )
})

test_that("Wizard-gate: data_updated UDEN data laaser trin 2 + 3", {
  skip_if_not_installed("shiny")
  tracker <- new_call_tracker()

  testthat::with_mocked_bindings(
    nav_select = mock_nav_select_fn(tracker),
    .package = "bslib",
    {
      testthat::with_mocked_bindings(
        enable = mock_shinyjs_fn(tracker, "enable"),
        disable = mock_shinyjs_fn(tracker, "disable"),
        .package = "shinyjs",
        {
          shiny::testServer(make_wizard_test_harness(), {
            app_state <- session$userData$app_state
            session$flushReact()
            init_count <- length(session$userData$custom_messages())
            init_nav <- length(tracker$nav)

            app_state$data$current_data <- NULL
            app_state$events$data_updated <- (app_state$events$data_updated %||% 0L) + 1L
            session$flushReact()

            msgs <- session$userData$custom_messages()
            new_msgs <- msgs[seq.int(init_count + 1L, length(msgs))]
            ids <- vapply(new_msgs, fmt_msg, character(1))

            expect_true("wizard-lock-step:2" %in% ids)
            expect_true("wizard-lock-step:3" %in% ids)

            # Auto-nav til upload skal vaere kaldt
            new_navs <- if (length(tracker$nav) > init_nav) {
              tracker$nav[seq.int(init_nav + 1L, length(tracker$nav))]
            } else {
              list()
            }
            upload_navs <- Filter(
              function(c) identical(c$selected, "upload"),
              new_navs
            )
            expect_gt(length(upload_navs), 0L)
          })
        }
      )
    }
  )
})

# ============================================================================
# SUITE: plot_ready styrer trin 3
# ============================================================================

test_that("Wizard-gate: plot_ready = TRUE unlocker trin 3 + completer trin 2", {
  skip_if_not_installed("shiny")
  tracker <- new_call_tracker()

  testthat::with_mocked_bindings(
    nav_select = mock_nav_select_fn(tracker),
    .package = "bslib",
    {
      testthat::with_mocked_bindings(
        enable = mock_shinyjs_fn(tracker, "enable"),
        disable = mock_shinyjs_fn(tracker, "disable"),
        .package = "shinyjs",
        {
          shiny::testServer(make_wizard_test_harness(), {
            app_state <- session$userData$app_state
            session$flushReact()
            init_count <- length(session$userData$custom_messages())

            app_state$visualization$plot_ready <- TRUE
            session$flushReact()

            msgs <- session$userData$custom_messages()
            new_msgs <- msgs[seq.int(init_count + 1L, length(msgs))]
            ids <- vapply(new_msgs, fmt_msg, character(1))

            expect_true("wizard-complete-step:2" %in% ids)
            expect_true("wizard-unlock-step:3" %in% ids)
          })
        }
      )
    }
  )
})

test_that("Wizard-gate: plot_ready = FALSE laaser trin 3 + uncompleter trin 2", {
  skip_if_not_installed("shiny")
  tracker <- new_call_tracker()

  testthat::with_mocked_bindings(
    nav_select = mock_nav_select_fn(tracker),
    .package = "bslib",
    {
      testthat::with_mocked_bindings(
        enable = mock_shinyjs_fn(tracker, "enable"),
        disable = mock_shinyjs_fn(tracker, "disable"),
        .package = "shinyjs",
        {
          shiny::testServer(make_wizard_test_harness(), {
            app_state <- session$userData$app_state

            # Toggle TRUE -> FALSE for ny observe-cycle
            app_state$visualization$plot_ready <- TRUE
            session$flushReact()

            init_count <- length(session$userData$custom_messages())

            app_state$visualization$plot_ready <- FALSE
            session$flushReact()

            msgs <- session$userData$custom_messages()
            new_msgs <- msgs[seq.int(init_count + 1L, length(msgs))]
            ids <- vapply(new_msgs, fmt_msg, character(1))

            expect_true("wizard-lock-step:3" %in% ids)
            expect_true("wizard-uncomplete-step:2" %in% ids)
          })
        }
      )
    }
  )
})
