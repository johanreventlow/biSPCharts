# test-bfhcharts-integration.R
# Salvage Fase 2: Opdateret til nuværende BFHcharts API
# create_spc_chart() er ikke eksporteret — brug BFHcharts::bfh_qic() i stedet.

test_that("BFHcharts bfh_qic kan oprette enkel run-chart", {
  skip_if_not_installed("BFHcharts")
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    Dato = seq.Date(from = as.Date("2024-01-01"), by = "week", length.out = 20),
    Taeller = c(
      15, 18, 20, 17, 19, 22, 21, 18, 20, 23,
      25, 24, 22, 26, 28, 27, 25, 29, 30, 28
    )
  )

  plot_result <- expect_no_error(
    BFHcharts::bfh_qic(
      data = test_data,
      x = Dato,
      y = Taeller,
      chart_type = "run",
      y_axis_unit = "count",
      chart_title = "Test Run Chart"
    )
  )

  expect_true(inherits(plot_result, "bfh_qic_result"))
})

test_that("BFHcharts bfh_qic kan oprette run-chart med faser", {
  skip_if_not_installed("BFHcharts")
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    Dato = seq.Date(from = as.Date("2024-01-01"), by = "week", length.out = 20),
    Taeller = c(
      15, 18, 20, 17, 19, 22, 21, 18, 20, 23,
      25, 24, 22, 26, 28, 27, 25, 29, 30, 28
    )
  )

  plot_result <- expect_no_error(
    BFHcharts::bfh_qic(
      data = test_data,
      x = Dato,
      y = Taeller,
      chart_type = "run",
      y_axis_unit = "count",
      part = 10,
      chart_title = "Test Run Chart med Faser"
    )
  )

  expect_true(inherits(plot_result, "bfh_qic_result"))
})

test_that("BFHcharts bfh_qic kan oprette P-chart med naevner", {
  skip_if_not_installed("BFHcharts")
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    Dato = seq.Date(from = as.Date("2024-01-01"), by = "week", length.out = 20),
    Taeller = c(
      5, 8, 10, 7, 9, 12, 11, 8, 10, 13,
      15, 14, 12, 16, 18, 17, 15, 19, 20, 18
    ),
    Naevner = c(
      50, 55, 60, 52, 58, 62, 61, 58, 60, 63,
      65, 64, 62, 66, 68, 67, 65, 69, 70, 68
    )
  )

  plot_result <- expect_no_error(
    BFHcharts::bfh_qic(
      data = test_data,
      x = Dato,
      y = Taeller,
      n = Naevner,
      chart_type = "p",
      y_axis_unit = "percent",
      chart_title = "Test P-Chart"
    )
  )

  expect_true(inherits(plot_result, "bfh_qic_result"))
})

test_that("BFHcharts bfh_qic haandterer target-vaerdi", {
  skip_if_not_installed("BFHcharts")
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    Dato = seq.Date(from = as.Date("2024-01-01"), by = "week", length.out = 20),
    Taeller = c(
      15, 18, 20, 17, 19, 22, 21, 18, 20, 23,
      25, 24, 22, 26, 28, 27, 25, 29, 30, 28
    )
  )

  plot_result <- expect_no_error(
    BFHcharts::bfh_qic(
      data = test_data,
      x = Dato,
      y = Taeller,
      chart_type = "run",
      y_axis_unit = "count",
      target_value = 25,
      target_text = "Maal: 25",
      chart_title = "Test med Target"
    )
  )

  expect_true(inherits(plot_result, "bfh_qic_result"))
})

test_that("BFHcharts to-trins workflow: bfh_qic + get_plot", {
  skip_if_not_installed("BFHcharts")
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    Dato = seq.Date(from = as.Date("2024-01-01"), by = "week", length.out = 20),
    Taeller = c(
      15, 18, 20, 17, 19, 22, 21, 18, 20, 23,
      25, 24, 22, 26, 28, 27, 25, 29, 30, 28
    )
  )

  # Trin 1: Kald bfh_qic
  bfh_result <- BFHcharts::bfh_qic(
    data = test_data,
    x = Dato,
    y = Taeller,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "To-trins test"
  )

  expect_true(inherits(bfh_result, "bfh_qic_result"))

  # Trin 2: Udtraek ggplot
  plot <- BFHcharts::get_plot(bfh_result)
  expect_s3_class(plot, "ggplot")
})

test_that("TODO Fase 3: BFHcharts::create_spc_chart er ikke eksporteret", {
  skip(paste0(
    "TODO Fase 3: R-bug afsloeret — BFHcharts::create_spc_chart() ikke eksporteret (#203-followup)\n",
    "Nuvaerende API: BFHcharts::bfh_qic() + BFHcharts::get_plot()\n",
    "Gammel API er fjernet fra BFHcharts namespace"
  ))
  skip_if_not_installed("BFHcharts")
  test_data <- data.frame(Dato = Sys.Date(), Taeller = 1L)
  expect_no_error(BFHcharts::create_spc_chart(data = test_data, x = Dato, y = Taeller))
})
