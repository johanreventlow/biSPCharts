# test-utils_server_event_listeners.R
# Direct contract tests for setup_event_listeners().

make_fake_observer <- function(name, state) {
  list(
    destroy = function() {
      state$destroyed <- c(state$destroyed, name)
      invisible(NULL)
    }
  )
}

make_event_registrar <- function(label, state) {
  force(label)
  function(...) {
    args <- list(...)
    register_observer <- args[[length(args)]]
    state$calls <- c(state$calls, label)
    observer_name <- paste0(label, "_observer")
    observer <- make_fake_observer(observer_name, state)
    registered <- register_observer(observer_name, observer)
    stats::setNames(list(registered), observer_name)
  }
}

test_that("setup_event_listeners orchestrates modular registrars and cleanup", {
  require_internal("setup_event_listeners", mode = "function")

  state <- new.env(parent = emptyenv())
  state$calls <- character()
  state$destroyed <- character()
  ended_callback <- NULL
  session <- list(
    onSessionEnded = function(fun) {
      ended_callback <<- fun
      invisible(NULL)
    }
  )

  testthat::local_mocked_bindings(
    observeEvent = function(eventExpr, handlerExpr, ...) {
      make_fake_observer("main_navbar_manual", state)
    },
    .package = "shiny"
  )
  testthat::local_mocked_bindings(
    register_data_lifecycle_events = make_event_registrar("data", state),
    register_autodetect_events = make_event_registrar("autodetect", state),
    register_ui_sync_events = make_event_registrar("ui", state),
    register_navigation_events = make_event_registrar("navigation", state),
    register_chart_type_events = make_event_registrar("chart", state),
    setup_wizard_gates = function(...) {
      state$calls <- c(state$calls, "wizard")
      invisible(NULL)
    },
    setup_paste_data_observers = function(...) {
      state$calls <- c(state$calls, "paste")
      invisible(NULL)
    },
    .package = "biSPCharts"
  )

  registry <- setup_event_listeners(
    app_state = create_app_state(),
    emit = create_emit_api(create_app_state()),
    input = list(main_navbar = NULL),
    output = list(),
    session = session,
    ui_service = NULL
  )

  expect_equal(
    state$calls,
    c("data", "autodetect", "ui", "navigation", "chart", "wizard", "paste")
  )
  expect_true(all(c(
    "data_observer", "autodetect_observer", "ui_observer",
    "navigation_observer", "chart_observer", "main_navbar_manual"
  ) %in% names(registry)))
  expect_true(is.function(ended_callback))

  ended_callback()
  expect_true(all(names(registry) %in% state$destroyed))
})

test_that("setup_event_listeners rejects duplicate optimized listener setup", {
  require_internal("setup_event_listeners", mode = "function")

  app_state <- create_app_state()
  app_state$optimized_listeners_active <- TRUE

  expect_error(
    setup_event_listeners(
      app_state = app_state,
      emit = create_emit_api(app_state),
      input = list(),
      output = list(),
      session = shiny::MockShinySession$new(),
      ui_service = NULL
    ),
    "optimized listeners are active"
  )
})
