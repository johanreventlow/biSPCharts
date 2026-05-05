# test-centerline-handling.R
# Sikrer at baseline (centerline) input anvendes identisk med målværdi

require_internal("build_qic_arguments", mode = "function")
require_internal("execute_qic_call", mode = "function")
require_internal("prepare_qic_data_parameters", mode = "function")
require_internal("validate_x_column_format", mode = "function")
require_internal("parse_danish_target", mode = "function")


get_centerline_from_qic <- function(qic_args, chart_type, config) {
  qic_result <- execute_qic_call(qic_args, chart_type = chart_type, config = config)
  unique(qic_result$cl)
}


test_that("centerline anvendes korrekt for decimale datasæt", {
  test_data <- data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "week", length.out = 8),
    Måling = c(0.55, 0.62, 0.58, 0.64, 0.6, 0.59, 0.63, 0.57),
    check.names = FALSE
  )

  config <- list(x_col = "Dato", y_col = "Måling", n_col = NULL)

  x_validation <- validate_x_column_format(test_data, config$x_col, "observation")
  prepared <- prepare_qic_data_parameters(test_data, config, x_validation, "i")

  input_value <- "80%"
  target_value <- parse_danish_target(input_value, test_data$Måling, "percent")
  centerline_value <- parse_danish_target(input_value, test_data$Måling, "percent")

  expect_equal(target_value, 0.8)
  expect_equal(centerline_value, 0.8)

  qic_args <- build_qic_arguments(
    data = prepared$data,
    x_col_for_qic = prepared$x_col_for_qic,
    y_col_name = prepared$y_col_name,
    n_col_name = prepared$n_col_name,
    chart_type = "i",
    freeze_position = NULL,
    part_positions = NULL,
    target_value = target_value,
    centerline_value = centerline_value
  )

  centerline_result <- get_centerline_from_qic(qic_args, "i", config)
  expect_true(all(abs(centerline_result - centerline_value) < 1e-8))
})


test_that("centerline anvendes korrekt for procentdatasæt med nævner", {
  test_data <- data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 6),
    `Antal succes` = c(80, 82, 79, 83, 81, 84),
    `Antal total` = rep(100, 6),
    check.names = FALSE
  )

  config <- list(x_col = "Dato", y_col = "Antal succes", n_col = "Antal total")

  x_validation <- validate_x_column_format(test_data, config$x_col, "observation")
  prepared <- prepare_qic_data_parameters(test_data, config, x_validation, "run")

  input_value <- "80%"
  target_value <- parse_danish_target(input_value, test_data$`Antal succes`, "percent")
  centerline_value <- parse_danish_target(input_value, test_data$`Antal succes`, "percent")

  expect_equal(target_value, 0.8)
  expect_equal(centerline_value, 0.8)

  qic_args <- build_qic_arguments(
    data = prepared$data,
    x_col_for_qic = prepared$x_col_for_qic,
    y_col_name = prepared$y_col_name,
    n_col_name = prepared$n_col_name,
    chart_type = "run",
    freeze_position = NULL,
    part_positions = NULL,
    target_value = target_value,
    centerline_value = centerline_value
  )

  centerline_result <- get_centerline_from_qic(qic_args, "run", config)
  expect_true(all(abs(centerline_result - centerline_value) < 1e-8))
})


test_that("prepare_qic_data_optimized bruger cl-parameter til baseline", {
  skip("Legacy optimized qic helper blev fjernet; centerline dækkes via aktiv qic-argument path ovenfor.")

  test_data <- data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "week", length.out = 10),
    Måling = c(72, 75, 71, 74, 76, 73, 75, 74, 72, 73),
    check.names = FALSE
  )

  config <- list(x_col = "Dato", y_col = "Måling", n_col = NULL)

  preprocessed <- preprocess_spc_data_optimized(test_data, config)

  centerline_value <- 74
  target_value <- 75

  qic_params <- prepare_qic_data_optimized(
    preprocessed_data = preprocessed,
    chart_type = "run",
    target_value = target_value,
    centerline_value = centerline_value,
    show_phases = FALSE,
    skift_column = NULL,
    frys_column = NULL
  )

  expect_equal(qic_params$target, target_value)
  expect_equal(qic_params$cl, centerline_value)
})


test_that("prepare_qic_data_optimized normaliserer referenceværdier for run charts med nævner", {
  skip("Legacy optimized qic helper blev fjernet; referenceværdi-normalisering dækkes via aktiv qic-argument path ovenfor.")

  test_data <- data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "week", length.out = 6),
    `Antal succes` = c(80, 82, 79, 83, 81, 84),
    `Antal total` = rep(100, 6),
    check.names = FALSE
  )

  config <- list(x_col = "Dato", y_col = "Antal succes", n_col = "Antal total")

  preprocessed <- preprocess_spc_data_optimized(test_data, config)

  centerline_value <- 80
  target_value <- 75

  qic_params <- prepare_qic_data_optimized(
    preprocessed_data = preprocessed,
    chart_type = "run",
    target_value = target_value,
    centerline_value = centerline_value,
    show_phases = FALSE,
    skift_column = NULL,
    frys_column = NULL
  )

  expect_equal(qic_params$target, target_value / 100)
  expect_equal(qic_params$cl, centerline_value / 100)
})
