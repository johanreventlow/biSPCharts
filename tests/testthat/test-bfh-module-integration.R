# Shinytest2 snapshot tests for BFHchart module integration
# Tests visual output of all supported chart types with BFHchart backend

library(testthat)

bfh_shinytest2_enabled <- identical(Sys.getenv("RUN_SHINYTEST2"), "1")

if (bfh_shinytest2_enabled && requireNamespace("shinytest2", quietly = TRUE)) {
  library(shinytest2)
}

skip_bfh_shinytest2 <- function() {
  skip_if(
    !bfh_shinytest2_enabled,
    "BFH shinytest2 visual tests are opt-in; set RUN_SHINYTEST2=1"
  )
  skip_if_not_installed("shinytest2")
}

# Test fixtures helper
create_test_csv <- function(chart_type, n_rows = 50, seed = 20251015) {
  set.seed(seed)

  base_data <- data.frame(
    Dato = seq.Date(Sys.Date() - n_rows + 1, Sys.Date(), by = "day"),
    Vaerdi = rnorm(n_rows, mean = 100, sd = 15)
  )

  # Add denominator for ratio charts
  if (chart_type %in% c("p", "c", "u")) {
    base_data$Naevner <- sample(50:200, n_rows, replace = TRUE)
  }

  base_data
}

# Helper to get app driver
get_app_driver <- function(name) {
  shinytest2::AppDriver$new(
    app_dir = test_path("../.."),
    name = name,
    variant = shinytest2::platform_variant(),
    height = 800,
    width = 1200
  )
}

# Helper to upload CSV via current upload input id
upload_test_data <- function(app, csv_path) {
  app$upload_file(direct_file_upload = csv_path)
  app$wait_for_idle(timeout = 5000)
}

# ==============================================================================
# Test: Run Chart with BFHchart Backend
# ==============================================================================

test_that("BFHchart module: Run chart renders correctly with BFHchart backend", {
  skip_bfh_shinytest2()

  # Create test data
  test_data <- create_test_csv("run")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  # Launch app
  app <- get_app_driver("bfh-run-chart")

  # Upload test data
  upload_test_data(app, temp_csv)

  # Configure chart
  app$set_inputs(
    chart_type = "Run",
    x_column = "Dato",
    y_column = "Vaerdi"
  )
  app$wait_for_idle(timeout = 5000)

  # Snapshot visual output
  app$expect_screenshot(
    selector = "#spc_plot_actual",
    name = "bfh-run-chart",
    threshold = 0.1 # Allow 10% pixel diff for anti-aliasing
  )

  # Verify plot rendered (check values)
  expect_true(app$get_value(output = "plot_ready"))

  # Cleanup
  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: I Chart with BFHchart Backend
# ==============================================================================

test_that("BFHchart module: I chart renders correctly", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("i")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-i-chart")

  upload_test_data(app, temp_csv)

  app$set_inputs(
    chart_type = "I",
    x_column = "Dato",
    y_column = "Vaerdi"
  )
  app$wait_for_idle(timeout = 5000)

  app$expect_screenshot(
    selector = "#spc_plot_actual",
    name = "bfh-i-chart",
    threshold = 0.1
  )

  expect_true(app$get_value(output = "plot_ready"))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: P Chart with BFHchart Backend (ratio chart with denominator)
# ==============================================================================

test_that("BFHchart module: P chart renders correctly with denominator", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("p")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-p-chart")

  upload_test_data(app, temp_csv)

  app$set_inputs(
    chart_type = "P",
    x_column = "Dato",
    y_column = "Vaerdi",
    n_column = "Naevner"
  )
  app$wait_for_idle(timeout = 5000)

  app$expect_screenshot(
    selector = "#spc_plot_actual",
    name = "bfh-p-chart",
    threshold = 0.1
  )

  expect_true(app$get_value(output = "plot_ready"))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: C Chart with BFHchart Backend (count data)
# ==============================================================================

test_that("BFHchart module: C chart renders correctly with count data", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("c")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-c-chart")

  upload_test_data(app, temp_csv)

  app$set_inputs(
    chart_type = "C",
    x_column = "Dato",
    y_column = "Vaerdi"
  )
  app$wait_for_idle(timeout = 5000)

  app$expect_screenshot(
    selector = "#spc_plot_actual",
    name = "bfh-c-chart",
    threshold = 0.1
  )

  expect_true(app$get_value(output = "plot_ready"))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: U Chart with BFHchart Backend (rate data with variable denominator)
# ==============================================================================

test_that("BFHchart module: U chart renders correctly with variable denominator", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("u")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-u-chart")

  upload_test_data(app, temp_csv)

  app$set_inputs(
    chart_type = "U",
    x_column = "Dato",
    y_column = "Vaerdi",
    n_column = "Naevner"
  )
  app$wait_for_idle(timeout = 5000)

  app$expect_screenshot(
    selector = "#spc_plot_actual",
    name = "bfh-u-chart",
    threshold = 0.1
  )

  expect_true(app$get_value(output = "plot_ready"))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: Freeze Period with BFHchart Backend
# ==============================================================================

test_that("BFHchart module: Freeze period renders correctly", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("run")
  test_data$Fryz <- c(rep(0, 30), rep(1, 20)) # Last 20 points frozen

  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-freeze-test")

  upload_test_data(app, temp_csv)

  app$set_inputs(
    chart_type = "Run",
    x_column = "Dato",
    y_column = "Vaerdi",
    frys_column = "Fryz"
  )
  app$wait_for_idle(timeout = 5000)

  app$expect_screenshot(
    selector = "#spc_plot_actual",
    name = "bfh-freeze-period",
    threshold = 0.1
  )

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: Comments/Notes with BFHchart Backend
# ==============================================================================

test_that("BFHchart module: Comments render correctly with BFHchart", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("run")
  test_data$Kommentar <- c(
    rep("", 45),
    "Intervention", "Intervention", "Intervention", "Intervention", "Intervention"
  )

  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-comments-test")

  upload_test_data(app, temp_csv)

  app$set_inputs(
    chart_type = "Run",
    x_column = "Dato",
    y_column = "Vaerdi",
    kommentar_column = "Kommentar"
  )
  app$wait_for_idle(timeout = 5000)

  app$expect_screenshot(
    selector = "#spc_plot_actual",
    name = "bfh-comments",
    threshold = 0.1
  )

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: Visual Regression Detection - No breaking changes
# ==============================================================================

test_that("BFHchart module: Visual output consistent across runs", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("run")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  # First run
  app1 <- get_app_driver("bfh-regression-1")
  upload_test_data(app1, temp_csv)
  app1$set_inputs(
    chart_type = "Run",
    x_column = "Dato",
    y_column = "Vaerdi"
  )
  app1$wait_for_idle(timeout = 5000)

  # Capture first screenshot
  app1$expect_screenshot(
    selector = "#spc_plot_actual",
    name = "bfh-regression-baseline",
    threshold = 0.1
  )

  app1$stop()

  # Second run (should match)
  app2 <- get_app_driver("bfh-regression-2")
  upload_test_data(app2, temp_csv)
  app2$set_inputs(
    chart_type = "Run",
    x_column = "Dato",
    y_column = "Vaerdi"
  )
  app2$wait_for_idle(timeout = 5000)

  # Capture second screenshot (should match baseline)
  app2$expect_screenshot(
    selector = "#spc_plot_actual",
    name = "bfh-regression-check",
    threshold = 0.1
  )

  app2$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: Module Output Structure
# ==============================================================================

test_that("BFHchart module: Output structure is correct", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("run")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-output-structure")

  upload_test_data(app, temp_csv)

  app$set_inputs(
    chart_type = "Run",
    x_column = "Dato",
    y_column = "Vaerdi"
  )
  app$wait_for_idle(timeout = 5000)

  # Check outputs exist
  expect_true(app$get_value(output = "plot_ready"))
  expect_true(!is.null(app$get_value(output = "spc_plot_actual")))

  # Check Anhøj results exist
  anhoej <- app$get_value(output = "anhoej_results")
  expect_true(!is.null(anhoej))

  app$stop()
  unlink(temp_csv)
})
