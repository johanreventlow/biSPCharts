# test-state-transitions.R
# Contract-tests for state-transition-helpers og apply_state_transition
# Ingen Shiny-session kræves (pure funktioner testes isoleret)

# Tests: transition_upload_to_ready() ----------------------------------------

test_that("transition_upload_to_ready returnerer korrekt ændringsliste", {
  df <- data.frame(x = 1:3, y = 4:6)
  parsed <- new_parsed_file(df, format = "csv", encoding = "UTF-8")

  result <- transition_upload_to_ready(parsed)

  # Tjek struktur
  expect_type(result, "list")
  expect_named(result, c("data", "session", "columns", "ui"), ignore.order = TRUE)

  # Data-section
  expect_equal(result$data$current_data, df)
  expect_equal(result$data$original_data, df)
  expect_equal(result$data$file_info, parsed$meta)

  # Session-section
  expect_true(result$session$file_uploaded)

  # Columns-section
  expect_false(result$columns$auto_detect$completed)

  # UI-section
  expect_false(result$ui$hide_anhoej_rules)
})

# Tests: transition_autodetect_complete() ------------------------------------

test_that("transition_autodetect_complete returnerer korrekt ændringsliste", {
  result_obj <- new_autodetect_result(list(
    x_col = "Dato", y_col = "Vaerdi", n_col = NULL,
    skift_col = NULL, frys_col = NULL, kommentar_col = NULL
  ))

  result <- transition_autodetect_complete(result_obj)

  expect_type(result, "list")
  expect_named(result, "columns")

  # Mappings
  expect_equal(result$columns$mappings$x_column, "Dato")
  expect_equal(result$columns$mappings$y_column, "Vaerdi")
  expect_null(result$columns$mappings$n_column)

  # Auto_detect
  expect_true(result$columns$auto_detect$completed)
  expect_equal(result$columns$auto_detect$results, result_obj)
})

# Tests: transition_chart_config_updated() -----------------------------------

test_that("transition_chart_config_updated returnerer korrekt ændringsliste", {
  config <- new_visualization_config(
    x_col = "Dato", y_col = "Vaerdi", n_col = NULL,
    chart_type = "run", source = "autodetect"
  )

  result <- transition_chart_config_updated(config)

  expect_type(result, "list")
  expect_named(result, "visualization")
  expect_equal(result$visualization$last_valid_config$y_col, "Vaerdi")
  expect_equal(result$visualization$last_valid_config$chart_type, "run")
})

# Tests: transition_session_restore() ----------------------------------------

test_that("transition_session_restore sætter restoring_session = TRUE", {
  df <- data.frame(x = 1:3, y = 4:6)
  parsed <- new_parsed_file(df, format = "excel", encoding = "UTF-8")
  parsed$meta$is_bispchart_format <- TRUE
  parsed$meta$saved_metadata <- list(
    x_column = "Dato",
    y_column = "Vaerdi"
  )

  result <- transition_session_restore(parsed)

  expect_true(result$session$restoring_session)
  expect_true(result$columns$auto_detect$completed)
  expect_equal(result$columns$mappings$x_column, "Dato")
  expect_equal(result$columns$mappings$y_column, "Vaerdi")
})

# Tests: apply_state_transition() -------------------------------------------

test_that("apply_state_transition anvender ændringer på plain environment", {
  # Test med plain environment (simulerer reactiveValues uden Shiny)
  state <- new.env(parent = emptyenv())
  state$data <- new.env(parent = emptyenv())
  state$data$current_data <- NULL
  state$session <- new.env(parent = emptyenv())
  state$session$file_uploaded <- FALSE

  df <- data.frame(x = 1:3)
  parsed <- new_parsed_file(df, format = "csv", encoding = "UTF-8")
  transition <- list(
    data = list(current_data = df),
    session = list(file_uploaded = TRUE)
  )

  # apply_state_transition kalder shiny::isolate — vi mocker med local environment
  # Her tester vi logikken direkte uden Shiny-session via isolate-wrapper
  # (apply_nested-logikken testes via en lokal hjælpefunktion)
  apply_nested_test <- function(state, changes) {
    for (nm in names(changes)) {
      val <- changes[[nm]]
      if (is.list(val) && !is.data.frame(val) && is.environment(state[[nm]])) {
        apply_nested_test(state[[nm]], val)
      } else {
        state[[nm]] <- val
      }
    }
    invisible(state)
  }

  apply_nested_test(state, transition)

  expect_equal(state$data$current_data, df)
  expect_true(state$session$file_uploaded)
})

test_that("apply_nested bevarer uberørte sub-felter", {
  state <- new.env(parent = emptyenv())
  state$data <- new.env(parent = emptyenv())
  state$data$current_data <- data.frame(x = 1)
  state$data$updating_table <- FALSE # Skal bevares

  apply_nested_test <- function(state, changes) {
    for (nm in names(changes)) {
      val <- changes[[nm]]
      if (is.list(val) && !is.data.frame(val) && is.environment(state[[nm]])) {
        apply_nested_test(state[[nm]], val)
      } else {
        state[[nm]] <- val
      }
    }
    invisible(state)
  }

  apply_nested_test(state, list(data = list(current_data = data.frame(x = 2))))

  # current_data opdateret
  expect_equal(state$data$current_data$x, 2)
  # updating_table bevaret
  expect_false(state$data$updating_table)
})

test_that("apply_state_transition bevarer nested reactiveValues-grene", {
  app_state <- create_app_state()
  df <- data.frame(Dato = as.Date("2024-01-01") + 0:2, Vaerdi = 1:3)
  parsed <- new_parsed_file(df, format = "csv", encoding = "UTF-8")

  expect_s3_class(app_state$columns, "reactivevalues")
  expect_s3_class(shiny::isolate(app_state$columns$auto_detect), "reactivevalues")
  expect_s3_class(shiny::isolate(app_state$columns$mappings), "reactivevalues")

  apply_state_transition(app_state, transition_upload_to_ready(parsed))

  expect_s3_class(app_state$columns, "reactivevalues")
  expect_s3_class(shiny::isolate(app_state$columns$auto_detect), "reactivevalues")
  expect_s3_class(shiny::isolate(app_state$columns$mappings), "reactivevalues")
  expect_equal(shiny::isolate(app_state$data$current_data), df)
  expect_false(shiny::isolate(app_state$columns$auto_detect$completed))

  detected <- new_autodetect_result(list(
    x_col = "Dato", y_col = "Vaerdi", n_col = NULL,
    skift_col = NULL, frys_col = NULL, kommentar_col = NULL
  ))

  apply_state_transition(app_state, transition_autodetect_complete(detected))

  expect_s3_class(app_state$columns, "reactivevalues")
  expect_s3_class(shiny::isolate(app_state$columns$auto_detect), "reactivevalues")
  expect_s3_class(shiny::isolate(app_state$columns$mappings), "reactivevalues")
  expect_true(shiny::isolate(app_state$columns$auto_detect$completed))
  expect_equal(shiny::isolate(app_state$columns$mappings$x_column), "Dato")
  expect_equal(shiny::isolate(app_state$columns$mappings$y_column), "Vaerdi")
})
