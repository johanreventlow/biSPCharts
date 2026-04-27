# test-ui-update-service-form.R
# Tests for create_form_update_service()

.make_mock_form_state <- function() {
  list(
    data = list(current_data = NULL),
    columns = list(auto_detect = list(frozen_until_next_trigger = FALSE)),
    ui = list(
      updating_programmatically = FALSE,
      queued_updates = list(),
      queue_processing = FALSE,
      performance_metrics = list(
        total_updates = 0L, queued_updates = 0L,
        avg_update_duration_ms = 0.0, queue_max_size = 0L
      ),
      memory_limits = list(max_queue_size = 50L)
    )
  )
}

test_that("create_form_update_service returnerer korrekt API", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_form_update_service(mock_session, .make_mock_form_state())

  expect_type(svc, "list")
  expect_true("update_form_fields" %in% names(svc))
  expect_true("reset_form_fields" %in% names(svc))
  expect_true("toggle_ui_element" %in% names(svc))
  expect_true("validate_form_fields" %in% names(svc))
  expect_true("show_user_feedback" %in% names(svc))
  expect_true("update_ui_conditionally" %in% names(svc))
  expect_equal(length(svc), 6)
})

test_that("form-service eksponerer IKKE kolonne-API", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_form_update_service(mock_session, .make_mock_form_state())

  expect_false("update_column_choices" %in% names(svc))
  expect_false("update_all_columns" %in% names(svc))
  expect_false("update_all_columns_from_state" %in% names(svc))
})

test_that("form_service oprettes uden column_service (column_service = NULL)", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  # Ingen fejl ved column_service = NULL
  expect_no_error(
    create_form_update_service(mock_session, .make_mock_form_state(), column_service = NULL)
  )
})

.run_validate <- function(svc, rules) {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyjs")
  result <- tryCatch(
    svc$validate_form_fields(rules, show_feedback = FALSE),
    error = function(e) NULL
  )
  if (is.null(result)) {
    fail(paste(
      "validate_form_fields skal kunne testes uden aktiv Shiny session",
      "når show_feedback = FALSE"
    ))
  }
  result
}

test_that("validate_form_fields: required-regel fejler ved tomt felt", {
  mock_session <- list(input = list(indicator_title = ""), sendCustomMessage = function(...) invisible(NULL))
  svc <- create_form_update_service(mock_session, .make_mock_form_state())
  result <- .run_validate(svc, list(indicator_title = list(required = TRUE)))
  expect_false(result$valid)
  expect_true("indicator_title" %in% names(result$errors))
})

test_that("validate_form_fields: numerisk regel fanger ikke-tal", {
  mock_session <- list(input = list(target_value = "ikke-et-tal"), sendCustomMessage = function(...) invisible(NULL))
  svc <- create_form_update_service(mock_session, .make_mock_form_state())
  result <- .run_validate(svc, list(target_value = list(type = "numeric")))
  expect_false(result$valid)
  expect_true("target_value" %in% names(result$errors))
})

test_that("validate_form_fields: gyldigt felt passerer validering", {
  mock_session <- list(input = list(target_value = "42"), sendCustomMessage = function(...) invisible(NULL))
  svc <- create_form_update_service(mock_session, .make_mock_form_state())
  result <- .run_validate(svc, list(target_value = list(type = "numeric")))
  expect_true(result$valid)
  expect_equal(length(result$errors), 0)
})

test_that("create_ui_update_service backward-compat wrapper merger begge APIs", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  state <- .make_mock_form_state()

  svc <- create_ui_update_service(mock_session, state)

  # Kolonne-API
  expect_true("update_column_choices" %in% names(svc))
  expect_true("update_all_columns" %in% names(svc))
  expect_true("update_all_columns_from_state" %in% names(svc))

  # Form-API
  expect_true("update_form_fields" %in% names(svc))
  expect_true("reset_form_fields" %in% names(svc))
  expect_true("toggle_ui_element" %in% names(svc))
  expect_true("validate_form_fields" %in% names(svc))
  expect_true("show_user_feedback" %in% names(svc))
  expect_true("update_ui_conditionally" %in% names(svc))

  expect_equal(length(svc), 9)
})
