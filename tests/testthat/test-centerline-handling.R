# test-centerline-handling.R
# Sikrer at baseline (centerline) input anvendes via aktiv BFHcharts-wrapper.

require_internal("generateSPCPlot", mode = "function")
require_internal("parse_danish_target", mode = "function")

test_that("centerline anvendes korrekt for decimale datasaet", {
  test_data <- data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "week", length.out = 8),
    Maaling = c(0.55, 0.62, 0.58, 0.64, 0.6, 0.59, 0.63, 0.57)
  )
  config <- list(x_col = "Dato", y_col = "Maaling", n_col = NULL)

  input_value <- "80%"
  target_value <- parse_danish_target(input_value, test_data$Maaling, "percent")
  centerline_value <- parse_danish_target(input_value, test_data$Maaling, "percent")

  result <- expect_warning(generateSPCPlot(
    data = test_data,
    config = config,
    chart_type = "i",
    target_value = target_value,
    centerline_value = centerline_value
  ), "Custom cl supplied")

  expect_equal(target_value, 0.8)
  expect_equal(centerline_value, 0.8)
  expect_true(all(abs(unique(result$qic_data$cl) - centerline_value) < 1e-8))
})

test_that("centerline anvendes korrekt for procentdatasaet med naevner", {
  test_data <- data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 6),
    Antal_succes = c(80, 82, 79, 83, 81, 84),
    Antal_total = rep(100, 6)
  )
  config <- list(x_col = "Dato", y_col = "Antal_succes", n_col = "Antal_total")

  input_value <- "80%"
  target_value <- parse_danish_target(input_value, test_data$Antal_succes, "percent")
  centerline_value <- parse_danish_target(input_value, test_data$Antal_succes, "percent")

  result <- expect_warning(generateSPCPlot(
    data = test_data,
    config = config,
    chart_type = "run",
    target_value = target_value,
    centerline_value = centerline_value
  ), "Custom cl supplied")

  expect_equal(target_value, 0.8)
  expect_equal(centerline_value, 0.8)
  expect_true(all(abs(unique(result$qic_data$cl) - centerline_value) < 1e-8))
})
