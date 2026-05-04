# test-input-sanitization.R
# Tests for robust handling of character(0), NA, and empty inputs

test_that("sanitize_selection handles edge case inputs correctly", {
  skip_if(
    !exists("sanitize_selection", where = asNamespace("biSPCharts"), mode = "function"),
    "sanitize_selection function not available in package namespace"
  )

  # Test character(0)
  expect_null(biSPCharts:::sanitize_selection(character(0)))

  # Test NULL
  expect_null(biSPCharts:::sanitize_selection(NULL))

  # Test empty string
  expect_null(biSPCharts:::sanitize_selection(""))

  # Test whitespace only
  expect_null(biSPCharts:::sanitize_selection("   "))

  # Test NA variants
  expect_null(biSPCharts:::sanitize_selection(NA_character_))
  expect_null(biSPCharts:::sanitize_selection(NA))

  # Test vector with all NAs
  expect_null(biSPCharts:::sanitize_selection(c(NA_character_, NA_character_)))

  # Test valid inputs
  expect_equal(biSPCharts:::sanitize_selection("valid"), "valid")
  expect_equal(biSPCharts:::sanitize_selection(c("valid", "second")), "valid")

  # Test mixed vectors
  expect_null(biSPCharts:::sanitize_selection(c(NA_character_, "valid")))
  expect_equal(biSPCharts:::sanitize_selection(c("valid", NA_character_)), "valid")
})

test_that("Reactive expressions handle character(0) inputs without crashing", {
  skip_if_not_installed("shiny")
  skip_if(
    !exists("sanitize_selection", where = asNamespace("biSPCharts"), mode = "function"),
    "sanitize_selection function not available"
  )

  # Test data
  test_data <- data.frame(
    Observation = 1:5,
    Value = c(15, 18, 22, 19, 25),
    Sample_Size = rep(100, 5)
  )

  # Test that reactive expressions with character(0) don't crash
  shiny::testServer(
    app = function(input, output, session) {
      # Simulate character(0) input scenarios
      values <- shiny::reactiveValues(
        current_data = test_data,
        x_column = character(0),
        y_column = character(0)
      )

      # Reactive that should handle edge cases safely
      safe_x_column <- shiny::reactive({
        biSPCharts:::sanitize_selection(values$x_column)
      })

      output$test_result <- shiny::renderText({
        x_col <- safe_x_column()
        if (is.null(x_col)) {
          "No valid column selected"
        } else {
          paste("Selected:", x_col)
        }
      })
    },
    {
      # Test that the reactive doesn't crash
      expect_true(is.character(output$test_result) || is.null(output$test_result))
    }
  )
})

test_that("Column selection UI updates handle empty states", {
  skip_if_not_installed("shiny")
  skip_if(
    !exists("create_app_state", mode = "function") ||
      !exists("update_column_choices_unified", mode = "function"),
    "Column choice update helpers not available"
  )

  app_state <- create_app_state()
  session <- shiny::MockShinySession$new()
  input <- shiny::reactiveValues()
  output <- list()

  shiny::isolate(app_state$data$current_data <- data.frame())

  expect_no_error(
    shiny::isolate(
      update_column_choices_unified(app_state, input, output, session)
    )
  )
})

test_that("Performance ikke påvirkes af character(0) handling", {
  skip_if_not_installed("microbenchmark")

  # Benchmark character(0) handling. suppressWarnings: microbenchmark
  # advarer "less accurate nanosecond times to avoid potential integer
  # overflows" på langtidsbench-targets; ej testrelevant.
  benchmark_result <- suppressWarnings(microbenchmark::microbenchmark(
    char_zero = biSPCharts:::sanitize_selection(character(0)),
    null_input = biSPCharts:::sanitize_selection(NULL),
    empty_string = biSPCharts:::sanitize_selection(""),
    valid_input = biSPCharts:::sanitize_selection("valid"),
    times = 100
  ))

  # All operations should be fast (under 1ms median)
  expect_true(all(benchmark_result$time < 1e6)) # 1ms in nanoseconds
})
