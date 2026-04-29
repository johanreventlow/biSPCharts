# test-async-export-task.R
# Tests for async export helpers i utils_async_helpers.R
#
# NOTE: shiny::ExtendedTask kan ikke testes fuldt ud uden AppDriver/shinytest2.
# Disse tests verificerer synkrone helper-funktioner: wrap_blocking_call() og
# make_extended_task_expr(). Full ExtendedTask lifecycle-test hører i
# tests/manual/ eller shinytest2 (CI opt-in).

test_that("wrap_blocking_call returnerer resultatet ved succes", {
  result <- wrap_blocking_call(
    expr = {
      list(value = 42, status = "ok")
    },
    on_error = function(e) NULL
  )

  expect_equal(result$value, 42)
  expect_equal(result$status, "ok")
})

test_that("wrap_blocking_call kalder on_error ved fejl og returnerer NULL", {
  error_caught <- NULL

  result <- wrap_blocking_call(
    expr = stop("test fejl"),
    on_error = function(e) {
      error_caught <<- e$message
      NULL
    }
  )

  expect_null(result)
  expect_equal(error_caught, "test fejl")
})

test_that("wrap_blocking_call returnerer fallback ved fejl", {
  fallback_value <- list(status = "error", value = NA)

  result <- wrap_blocking_call(
    expr = stop("noget gik galt"),
    on_error = function(e) fallback_value
  )

  expect_equal(result$status, "error")
})

test_that("wrap_blocking_call håndterer NULL-returværdi korrekt", {
  result <- wrap_blocking_call(
    expr = NULL,
    on_error = function(e) "fejl"
  )

  expect_null(result)
})

test_that("validate_ai_prerequisites returnerer FALSE når api_available er FALSE", {
  expect_false(validate_ai_prerequisites(has_spc_data = TRUE, api_available = FALSE))
})

test_that("validate_ai_prerequisites returnerer FALSE når has_spc_data er FALSE", {
  expect_false(validate_ai_prerequisites(has_spc_data = FALSE, api_available = TRUE))
})

test_that("validate_ai_prerequisites returnerer TRUE når begge er TRUE", {
  expect_true(validate_ai_prerequisites(has_spc_data = TRUE, api_available = TRUE))
})
