# test-fct_visualization_config_pure.R
# Unit-tests for build_visualization_config() og VisualizationConfig S3-struktur
# Ingen Shiny-session kræves

# Tests: prioriteringsrækkefølge --------------------------------------------

test_that("manuel override vinder over autodetect", {
  autodetect <- structure(
    list(x_col = "AutoX", y_col = "AutoY", n_col = NULL),
    class = "AutodetectResult"
  )

  result <- build_visualization_config(
    autodetect     = autodetect,
    user_overrides = list(x_col = "ManualX", y_col = "ManualY", chart_type = "run")
  )

  expect_equal(result$y_col, "ManualY")
  expect_equal(result$x_col, "ManualX")
  expect_equal(result$source, "manual")
})

test_that("autodetect bruges som fallback når ingen manuel override", {
  autodetect <- structure(
    list(x_col = "AutoX", y_col = "AutoY", n_col = NULL),
    class = "AutodetectResult"
  )

  result <- build_visualization_config(
    autodetect     = autodetect,
    user_overrides = list(chart_type = "run")
  )

  expect_equal(result$y_col, "AutoY")
  expect_equal(result$source, "autodetect")
})

test_that("mappings bruges som fallback ved session-restore", {
  result <- build_visualization_config(
    autodetect = NULL,
    user_overrides = list(
      chart_type = "run",
      mappings = list(
        x_column = "MappedX",
        y_column = "MappedY",
        n_column = NULL
      )
    )
  )

  expect_equal(result$y_col, "MappedY")
  expect_equal(result$source, "mapping")
})

test_that("returner NULL hvis ingen y_col kan bestemmes", {
  result <- build_visualization_config(
    autodetect     = NULL,
    user_overrides = list(chart_type = "run")
  )

  expect_null(result)
})

# Tests: kolonne-validering mod data ----------------------------------------

test_that("ugyldige kolonnenavne filtreres fra når data er givet", {
  data <- data.frame(Dato = Sys.Date(), Vaerdi = 10)
  autodetect <- structure(
    list(x_col = "UGYLDIG_X", y_col = "Vaerdi", n_col = "UGYLDIG_N"),
    class = "AutodetectResult"
  )

  result <- build_visualization_config(
    data       = data,
    autodetect = autodetect
  )

  expect_s3_class(result, "VisualizationConfig")
  expect_null(result$x_col) # UGYLDIG_X ikke i data
  expect_equal(result$y_col, "Vaerdi")
  expect_null(result$n_col) # UGYLDIG_N ikke i data
})

test_that("returner NULL hvis y_col ikke eksisterer i data", {
  data <- data.frame(Dato = Sys.Date(), AndenKolonne = 10)
  autodetect <- structure(
    list(x_col = NULL, y_col = "EKSISTERER_IKKE", n_col = NULL),
    class = "AutodetectResult"
  )

  result <- build_visualization_config(
    data       = data,
    autodetect = autodetect
  )

  expect_null(result)
})

# Tests: VisualizationConfig-struktur ----------------------------------------

test_that("VisualizationConfig har korrekte felter", {
  autodetect <- structure(
    list(x_col = "X", y_col = "Y", n_col = "N"),
    class = "AutodetectResult"
  )

  result <- build_visualization_config(
    autodetect     = autodetect,
    user_overrides = list(chart_type = "p")
  )

  expect_named(result, c("x_col", "y_col", "n_col", "chart_type", "source"), ignore.order = TRUE)
  expect_equal(result$chart_type, "p")
})

test_that("print.VisualizationConfig kører uden fejl", {
  autodetect <- structure(
    list(x_col = "X", y_col = "Y", n_col = NULL),
    class = "AutodetectResult"
  )

  result <- build_visualization_config(
    autodetect     = autodetect,
    user_overrides = list(chart_type = "run")
  )

  expect_output(print(result), "VisualizationConfig")
})

# Tests: new_visualization_config konstruktør ---------------------------------

test_that("new_visualization_config opretter korrekt S3-objekt", {
  result <- new_visualization_config(
    x_col      = "Dato",
    y_col      = "Vaerdi",
    n_col      = NULL,
    chart_type = "run",
    source     = "autodetect"
  )

  expect_s3_class(result, "VisualizationConfig")
  expect_equal(result$source, "autodetect")
})
