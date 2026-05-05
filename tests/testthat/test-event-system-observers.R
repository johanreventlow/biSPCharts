# test-event-system-observers.R
# Tests for event system observer behavior using production handlers.

library(testthat)
library(shiny)

make_event_app_state <- function(data = NULL) {
  app_state <- new.env(parent = emptyenv())
  app_state$data <- shiny::reactiveValues(current_data = data)
  app_state
}

make_emit_recorder <- function() {
  log <- new.env(parent = emptyenv())
  log$events <- character()

  record <- function(event) {
    force(event)
    function(...) {
      log$events <- c(log$events, event)
      invisible(NULL)
    }
  }

  list(
    emit = list(
      auto_detection_started = record("auto_detection_started"),
      navigation_changed = record("navigation_changed"),
      visualization_update_needed = record("visualization_update_needed")
    ),
    events = function() log$events
  )
}

test_that("resolve_column_update_reason correctly identifies contexts", {
  fn <- require_internal("resolve_column_update_reason", mode = "function")

  expect_equal(fn("table_edit"), "edit")
  expect_equal(fn("column_change"), "edit")
  expect_equal(fn("modify_data"), "edit")

  expect_equal(fn("session_restore"), "session")
  expect_equal(fn("Session_Start"), "session")

  expect_equal(fn("file_upload"), "upload")
  expect_equal(fn("data_loaded"), "upload")
  expect_equal(fn("new_file"), "upload")

  expect_equal(fn(NULL), "manual")
  expect_equal(fn("unknown_context"), "manual")
})

test_that("classify_update_context routes known production contexts", {
  classify <- require_internal("classify_update_context", mode = "function")

  expect_equal(classify(list(context = "file_upload")), "load")
  expect_equal(classify(list(context = "paste_data")), "load")
  expect_equal(classify(list(context = "table_cells_edited")), "table_edit")
  expect_equal(classify(list(context = "session_restore")), "session_restore")
  expect_equal(classify(list(context = "column_change")), "data_change")
  expect_equal(classify(NULL), "general")
})

test_that("handle_load_context triggers auto-detection only when data exists", {
  handle_load <- require_internal("handle_load_context", mode = "function")

  recorder <- make_emit_recorder()
  shiny::isolate(handle_load(make_event_app_state(data.frame(x = 1:3)), recorder$emit))
  expect_equal(recorder$events(), "auto_detection_started")

  recorder <- make_emit_recorder()
  shiny::isolate(handle_load(make_event_app_state(NULL), recorder$emit))
  expect_equal(recorder$events(), character())
})

test_that("handle_table_edit_context updates plot path without auto-detection", {
  handle_table_edit <- require_internal("handle_table_edit_context", mode = "function")

  recorder <- make_emit_recorder()
  handle_table_edit(make_event_app_state(data.frame(x = 1:3)), recorder$emit)

  expect_equal(recorder$events(), c("navigation_changed", "visualization_update_needed"))
  expect_false("auto_detection_started" %in% recorder$events())
})

test_that("handle_data_update_by_context dispatches load and table edit contexts", {
  dispatch <- require_internal("handle_data_update_by_context", mode = "function")

  recorder <- make_emit_recorder()
  shiny::isolate(dispatch(
    update_context = list(context = "file_upload"),
    app_state = make_event_app_state(data.frame(x = 1:3)),
    emit = recorder$emit,
    input = NULL,
    output = NULL,
    session = NULL,
    ui_service = NULL
  ))
  expect_equal(recorder$events(), "auto_detection_started")

  recorder <- make_emit_recorder()
  dispatch(
    update_context = list(context = "table_cells_edited"),
    app_state = make_event_app_state(data.frame(x = 1:3)),
    emit = recorder$emit,
    input = NULL,
    output = NULL,
    session = NULL,
    ui_service = NULL
  )
  expect_equal(recorder$events(), c("navigation_changed", "visualization_update_needed"))
})

test_that("state transitions encode upload and autodetect production state", {
  transition_upload <- require_internal("transition_upload_to_ready", mode = "function")
  transition_autodetect <- require_internal("transition_autodetect_complete", mode = "function")

  parsed_file <- structure(
    list(
      data = data.frame(Dato = as.Date("2024-01-01") + 0:2, Vaerdi = 1:3),
      meta = list(filename = "test.csv")
    ),
    class = "ParsedFile"
  )

  upload <- transition_upload(parsed_file)
  expect_identical(upload$data$current_data, parsed_file$data)
  expect_false(upload$columns$auto_detect$in_progress)
  expect_false(upload$columns$auto_detect$completed)

  result <- structure(
    list(
      x_col = "Dato",
      y_col = "Vaerdi",
      n_col = NULL,
      skift_col = NULL,
      frys_col = NULL,
      kommentar_col = NULL,
      timestamp = Sys.time()
    ),
    class = "AutodetectResult"
  )

  autodetect <- transition_autodetect(result)
  expect_false(autodetect$columns$auto_detect$in_progress)
  expect_true(autodetect$columns$auto_detect$completed)
  expect_equal(autodetect$columns$mappings$x_column, "Dato")
  expect_equal(autodetect$columns$mappings$y_column, "Vaerdi")
})
