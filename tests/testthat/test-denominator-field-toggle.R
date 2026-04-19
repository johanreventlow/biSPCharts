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

test_that("prepare_qic_data_parameters omitter n for irrelevante typer", {
  # Minimal data og config
  data <- data.frame(
    Dato = 1:5,
    Tæller = c(1, 2, 3, 4, 5),
    Nævner = c(10, 10, 10, 10, 10)
  )
  config <- list(x_col = "Dato", y_col = "Tæller", n_col = "Nævner")

  # Simpel x_validation uden datokonvertering
  x_validation <- list(is_date = FALSE, x_data = 1:nrow(data))

  # For p-kort skal n medtages
  params_p <- prepare_qic_data_parameters(data, config, x_validation, chart_type = "p")
  expect_equal(params_p$n_col_name, "Nævner")

  # For i-kort skal n udelades
  params_i <- prepare_qic_data_parameters(data, config, x_validation, chart_type = "i")
  expect_null(params_i$n_col_name)
})
