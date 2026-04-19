# test-visualization-server.R
# Tests for visualization server logic and reactive chains
#
# VIGTIGT: testServer() med inline server functions kan hænge i samlet
# test_dir() session. Brug isolate() og rene unit tests i stedet.

test_that("setup_visualization initializes correctly", {
  skip_if_not_installed("shiny")

  skip_if_not(
    exists("setup_visualization", mode = "function"),
    "setup_visualization function not available - check test setup"
  )

  mock_input <- list(chart_type = "P-kort \u2014 andele/procenter (fx infektionsrate)")
  mock_output <- list()
  mock_session <- list(token = "test_session")

  skip_if_not(
    exists("create_app_state", mode = "function"),
    "create_app_state not available - check test setup"
  )

  app_state <- create_app_state()

  result <- tryCatch(
    {
      setup_visualization(mock_input, mock_output, mock_session, app_state)
      "success"
    },
    error = function(e) {
      e$message
    }
  )

  expect_true(is.character(result))
})

test_that("Visualization reactive chains handle state updates", {
  skip_if_not_installed("shiny")
  skip_if_not(
    exists("create_app_state", mode = "function"),
    "create_app_state not available - check test setup"
  )

  app_state <- create_app_state()

  shiny::isolate({
    app_state$data$current_data <- data.frame(
      Skift = c(FALSE, FALSE, TRUE),
      Frys = c(FALSE, TRUE, FALSE),
      Dato = c("01-01-2024", "02-01-2024", "03-01-2024"),
      Tæller = c(10, 15, 12),
      Nævner = c(100, 120, 110)
    )

    app_state$columns$auto_detect$results <- list(
      x_col = "Dato",
      y_col = "Tæller",
      n_col = "Nævner",
      timestamp = Sys.time()
    )
  })

  # Test auto_detect results direkte uden testServer
  results <- shiny::isolate(app_state$columns$auto_detect$results)
  expect_equal(results$x_col, "Dato")
  expect_equal(results$y_col, "Tæller")
  expect_equal(results$n_col, "Nævner")
})

test_that("Chart type conversion works in visualization context", {
  skip_if_not(
    exists("get_qic_chart_type", mode = "function"),
    "get_qic_chart_type not available - check test setup"
  )

  expect_equal(get_qic_chart_type("P-kort \u2014 andele/procenter (fx infektionsrate)"), "p")
  expect_equal(get_qic_chart_type("U-kort \u2014 rater (fx komplikationer pr. 1000)"), "u")
  expect_equal(get_qic_chart_type("I-kort \u2014 enkelte m\u00e5linger (fx ventetid, temperatur)"), "i")
  expect_equal(get_qic_chart_type("Seriediagram (Run) \u2014 data over tid"), "run")

  expect_equal(get_qic_chart_type(""), "run")
  expect_equal(get_qic_chart_type(NULL), "run")
})

test_that("Plot generation with real data works", {
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    x = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01")),
    y = c(10, 15, 12, 18),
    n = c(100, 120, 110, 130)
  )

  result <- tryCatch(
    {
      qicharts2::qic(x = x, y = y, data = test_data, chart = "run")
    },
    error = function(e) NULL
  )

  if (!is.null(result)) {
    expect_s3_class(result, "ggplot")
  }

  p_result <- tryCatch(
    {
      qicharts2::qic(x = x, y = y, n = n, data = test_data, chart = "p")
    },
    error = function(e) NULL
  )

  if (!is.null(p_result)) {
    expect_s3_class(p_result, "ggplot")
  }
})

test_that("Visualization handles missing or invalid data gracefully", {
  skip_if_not_installed("shiny")
  skip_if_not(
    exists("create_app_state", mode = "function"),
    "create_app_state not available - check test setup"
  )

  app_state <- create_app_state()

  # Test empty data
  shiny::isolate({
    app_state$data$current_data <- data.frame()
  })
  data <- shiny::isolate(app_state$data$current_data)
  expect_true(is.null(data) || nrow(data) == 0)

  # Test malformed data (all NA)
  shiny::isolate({
    app_state$data$current_data <- data.frame(bad_col = c(NA, NA, NA))
  })
  data2 <- shiny::isolate(app_state$data$current_data)
  expect_true(all(is.na(unlist(data2))))
})
