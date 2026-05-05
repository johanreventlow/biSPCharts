# test-utils_server_server_management.R
# Direct contract tests for server session-management helpers.

make_session_management_emit <- function() {
  calls <- new.env(parent = emptyenv())
  calls$data_updated <- character()
  calls$navigation_changed <- 0L

  list(
    emit = list(
      data_updated = function(context = NULL, ...) {
        calls$data_updated <- c(calls$data_updated, context %||% "")
      },
      navigation_changed = function(...) {
        calls$navigation_changed <- calls$navigation_changed + 1L
      }
    ),
    calls = calls
  )
}

make_capture_session <- function() {
  session <- shiny::MockShinySession$new()
  messages <- list()
  session$sendCustomMessage <- function(type, message) {
    messages[[length(messages) + 1L]] <<- list(type = type, message = message)
    invisible(NULL)
  }
  list(session = session, messages = function() messages)
}

test_that("setup_session_management registers session management observers", {
  require_internal("setup_session_management", mode = "function")

  registered <- list()
  testthat::local_mocked_bindings(
    observeEvent = function(eventExpr, handlerExpr, ..., ignoreNULL = TRUE, ignoreInit = FALSE, once = FALSE) {
      registered[[length(registered) + 1L]] <<- list(
        ignoreNULL = ignoreNULL,
        ignoreInit = ignoreInit,
        once = once
      )
      list(destroy = function() invisible(NULL))
    },
    .package = "shiny"
  )

  emit <- make_session_management_emit()$emit
  setup_session_management(
    input = list(),
    output = list(),
    session = shiny::MockShinySession$new(),
    app_state = create_app_state(),
    emit = emit,
    ui_service = NULL
  )

  expect_length(registered, 4L)
  expect_true(registered[[1L]]$ignoreNULL)
  expect_true(registered[[2L]]$ignoreInit)
  expect_true(registered[[2L]]$once)
})

test_that("restore_metadata delegates complete metadata to ui_service", {
  require_internal("restore_metadata", mode = "function")

  received <- NULL
  ui_service <- list(
    update_form_fields = function(metadata, fields = NULL) {
      received <<- list(metadata = metadata, fields = fields)
    }
  )
  metadata <- list(
    chart_type = "p",
    x_column = "Dato",
    y_column = "Taeller",
    active_tab = "eksporter"
  )

  restore_metadata(shiny::MockShinySession$new(), metadata, ui_service)

  expect_equal(received$metadata, metadata)
  expect_null(received$fields)
})

test_that("collect_metadata falls back to app_state mappings for blank column inputs", {
  require_internal("collect_metadata", mode = "function")

  app_state <- create_app_state()
  shiny::isolate({
    app_state$columns$mappings$x_column <- "Dato"
    app_state$columns$mappings$y_column <- "Taeller"
    app_state$columns$mappings$kommentar_column <- "Note"
  })
  input <- list(
    x_column = "",
    y_column = NULL,
    n_column = "",
    skift_column = "",
    frys_column = "",
    kommentar_column = "",
    chart_type = "run",
    y_axis_unit = "count",
    main_navbar = "eksporter"
  )

  metadata <- collect_metadata(input, app_state)

  expect_equal(metadata$x_column, "Dato")
  expect_equal(metadata$y_column, "Taeller")
  expect_equal(metadata$kommentar_column, "Note")
  expect_equal(metadata$active_tab, "eksporter")
})

test_that("reset_to_empty_session clears storage, resets state, and emits events with ui_service", {
  require_internal("reset_to_empty_session", mode = "function")

  app_state <- create_app_state()
  shiny::isolate({
    app_state$data$current_data <- data.frame(old = 1:3)
    app_state$data$original_data <- data.frame(old = 1:3)
    app_state$session$file_uploaded <- TRUE
    app_state$session$last_save_time <- Sys.time()
    app_state$columns$auto_detect$completed <- TRUE
    app_state$ui$hide_anhoej_rules <- FALSE
  })
  session_capture <- make_capture_session()
  emit_bundle <- make_session_management_emit()
  ui_calls <- new.env(parent = emptyenv())
  ui_calls$reset <- 0L
  ui_service <- list(
    reset_form_fields = function() {
      ui_calls$reset <- ui_calls$reset + 1L
    }
  )

  testthat::local_mocked_bindings(
    reset = function(id) invisible(NULL),
    .package = "shinyjs"
  )
  testthat::local_mocked_bindings(
    autodetect_engine = function(...) list(),
    .package = "biSPCharts"
  )

  shiny::isolate(
    reset_to_empty_session(
      session = session_capture$session,
      app_state = app_state,
      emit = emit_bundle$emit,
      ui_service = ui_service
    )
  )

  expect_equal(session_capture$messages()[[1L]]$type, "clearAppState")
  expect_true(shiny::isolate(app_state$ui$hide_anhoej_rules))
  expect_false(shiny::isolate(app_state$session$file_uploaded))
  expect_true(shiny::isolate(app_state$session$user_started_session))
  expect_null(shiny::isolate(app_state$data$original_data))
  expect_false(shiny::isolate(app_state$columns$auto_detect$completed))
  expect_equal(emit_bundle$calls$data_updated, "new_session")
  expect_equal(emit_bundle$calls$navigation_changed, 1L)
  expect_equal(ui_calls$reset, 1L)
})

test_that("reset_to_empty_session fallback works without ui_service", {
  require_internal("reset_to_empty_session", mode = "function")

  app_state <- create_app_state()
  session_capture <- make_capture_session()
  emit_bundle <- make_session_management_emit()
  select_updates <- character()
  text_updates <- character()

  testthat::local_mocked_bindings(
    updateSelectizeInput = function(session, inputId, ...) {
      select_updates <<- c(select_updates, inputId)
      invisible(NULL)
    },
    updateTextInput = function(session, inputId, ...) {
      text_updates <<- c(text_updates, inputId)
      invisible(NULL)
    },
    .package = "shiny"
  )
  testthat::local_mocked_bindings(
    reset = function(id) invisible(NULL),
    .package = "shinyjs"
  )
  testthat::local_mocked_bindings(
    autodetect_engine = function(...) list(),
    .package = "biSPCharts"
  )

  expect_error(
    shiny::isolate(
      reset_to_empty_session(
        session = session_capture$session,
        app_state = app_state,
        emit = emit_bundle$emit,
        ui_service = NULL
      )
    ),
    NA
  )

  expect_true(all(c(
    "chart_type", "y_axis_unit", "x_column", "y_column", "n_column",
    "skift_column", "frys_column", "kommentar_column"
  ) %in% select_updates))
  expect_true(all(c("target_value", "centerline_value") %in% text_updates))
})

test_that("handle_clear_saved_request resets immediately only when no data or settings exist", {
  require_internal("handle_clear_saved_request", mode = "function")

  app_state <- create_app_state()
  reset_calls <- 0L
  modal_calls <- 0L
  notifications <- character()

  testthat::local_mocked_bindings(
    reset_to_empty_session = function(...) {
      reset_calls <<- reset_calls + 1L
      invisible(NULL)
    },
    show_clear_confirmation_modal = function(...) {
      modal_calls <<- modal_calls + 1L
      invisible(NULL)
    },
    .package = "biSPCharts"
  )
  testthat::local_mocked_bindings(
    showNotification = function(ui, ...) {
      notifications <<- c(notifications, as.character(ui))
      invisible(NULL)
    },
    .package = "shiny"
  )

  shiny::isolate(
    handle_clear_saved_request(
      input = list(),
      session = shiny::MockShinySession$new(),
      app_state = app_state,
      emit = make_session_management_emit()$emit,
      ui_service = NULL
    )
  )
  expect_equal(reset_calls, 1L)
  expect_equal(modal_calls, 0L)
  expect_equal(notifications, "Ny session startet")

  shiny::isolate(app_state$data$current_data <- data.frame(x = 1))
  shiny::isolate(
    handle_clear_saved_request(
      input = list(),
      session = shiny::MockShinySession$new(),
      app_state = app_state,
      emit = make_session_management_emit()$emit,
      ui_service = NULL
    )
  )
  expect_equal(reset_calls, 1L)
  expect_equal(modal_calls, 1L)
})
