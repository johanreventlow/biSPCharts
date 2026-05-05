test_that("chart_type_requires_denominator maps correctly", {
  # Supporterede typer der kræver nævner (run, p, u)
  expect_true(chart_type_requires_denominator("run"))
  expect_true(chart_type_requires_denominator("p"))
  expect_true(chart_type_requires_denominator("u"))

  # Supporterede typer uden nævner-krav (i, c)
  expect_false(chart_type_requires_denominator("i"))
  expect_false(chart_type_requires_denominator("c"))

  # Ikke-supporterede typer (mr, pp, up, g, t) behandles bevidst IKKE her —
  # get_qic_chart_type() falder tilbage til "run" for ukendte typer, hvilket
  # ville give false positives. Tilføj assertions hvis/når typerne aktiveres
  # i CHART_TYPES_EN.
})

test_that("generateSPCPlot accepterer n_col for I-kort uden legacy qic-preparation", {
  data <- data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "week", length.out = 5),
    Taeller = c(1, 2, 3, 4, 5),
    Naevner = c(10, 10, 10, 10, 10)
  )
  config <- list(x_col = "Dato", y_col = "Taeller", n_col = "Naevner")

  result <- generateSPCPlot(data, config, chart_type = "i")

  expect_s3_class(result$plot, "ggplot")
  expect_true("y" %in% names(result$qic_data))
})
