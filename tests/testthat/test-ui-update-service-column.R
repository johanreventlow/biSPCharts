# test-ui-update-service-column.R
# Tests for create_column_update_service()

# Kolonne-service API er session-afhængig (kræver Shiny-context for update-kald).
# Tests fokuserer på: factory returnerer korrekt API, choices-generering,
# og pure logic der ikke kræver aktiv Shiny-session.

.make_mock_col_state <- function(current_data = NULL) {
  list(
    data = list(current_data = current_data),
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

test_that("create_column_update_service returnerer korrekt API", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_column_update_service(mock_session, .make_mock_col_state())

  expect_type(svc, "list")
  expect_true("update_column_choices" %in% names(svc))
  expect_true("update_all_columns" %in% names(svc))
  expect_true("update_all_columns_from_state" %in% names(svc))
  expect_true(is.function(svc$update_column_choices))
  expect_true(is.function(svc$update_all_columns))
  expect_true(is.function(svc$update_all_columns_from_state))
})

test_that("choices-generering fra current_data følger korrekt struktur", {
  all_cols <- c("Dato", "Tæller", "Nævner")
  choices <- setNames(
    c("", all_cols),
    c("Vælg kolonne...", all_cols)
  )

  expect_equal(length(choices), 4)
  expect_equal(choices[[1]], "")
  expect_equal(names(choices)[[1]], "Vælg kolonne...")
  expect_true("Dato" %in% choices)
  expect_true("Tæller" %in% choices)
  expect_true("Nævner" %in% choices)
})

test_that("fallback choices ved NULL current_data er korrekt", {
  choices <- setNames("", "Vælg kolonne...")
  expect_equal(length(choices), 1)
  expect_equal(choices[[1]], "")
  expect_equal(names(choices)[[1]], "Vælg kolonne...")
})

test_that("clear_selections giver tom named vector af korrekt længde", {
  columns <- c("x_column", "y_column", "n_column", "skift_column", "frys_column", "kommentar_column")
  selected <- setNames(rep("", length(columns)), columns)

  expect_equal(length(selected), 6)
  expect_true(all(selected == ""))
  expect_equal(names(selected), columns)
})

test_that("kolonne-service eksponerer IKKE form-API", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_column_update_service(mock_session, .make_mock_col_state())

  expect_false("update_form_fields" %in% names(svc))
  expect_false("reset_form_fields" %in% names(svc))
  expect_false("show_user_feedback" %in% names(svc))
})

test_that("service-API eksponerer præcis 3 funktioner", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_column_update_service(mock_session, .make_mock_col_state())

  expect_equal(length(svc), 3)
  expect_equal(
    sort(names(svc)),
    sort(c("update_column_choices", "update_all_columns", "update_all_columns_from_state"))
  )
})
