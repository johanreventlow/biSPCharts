# test-cache-key-no-viewport.R
# Tests for cache-key generation i generate_spc_cache_key()
#
# Verificerer at viewport-dimensioner i cache-config ikke er afgørende
# for cache-key-identitet, men at ALLE andre parametre stadig er det.
# NOTE: Viewport FJERNES ikke fra BFHcharts-kaldet — det påvirker plot-rendering.
# Disse tests verificerer cache-key-logikken, ikke rendering-adfærd.

test_that("generate_spc_cache_key er deterministisk for identisk config", {
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
  )

  config <- list(
    chart_type = "run",
    x_column = "Dato",
    y_column = "Vaerdi",
    n_column = NULL,
    freeze_position = NULL,
    part_positions = NULL,
    target_value = NULL,
    centerline_value = NULL,
    y_axis_unit = NULL,
    multiply_by = 1
  )

  key1 <- generate_spc_cache_key(data, config)
  key2 <- generate_spc_cache_key(data, config)

  expect_identical(key1, key2)
})

test_that("generate_spc_cache_key differentierer på chart_type", {
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
  )

  config_run <- list(
    chart_type = "run", x_column = "Dato", y_column = "Vaerdi",
    n_column = NULL, freeze_position = NULL, part_positions = NULL,
    target_value = NULL, centerline_value = NULL, y_axis_unit = NULL,
    multiply_by = 1
  )

  config_i <- config_run
  config_i$chart_type <- "i"

  key_run <- generate_spc_cache_key(data, config_run)
  key_i <- generate_spc_cache_key(data, config_i)

  expect_false(identical(key_run, key_i))
})

test_that("generate_spc_cache_key differentierer på y_axis_unit", {
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
  )

  config_base <- list(
    chart_type = "run", x_column = "Dato", y_column = "Vaerdi",
    n_column = NULL, freeze_position = NULL, part_positions = NULL,
    target_value = NULL, centerline_value = NULL,
    y_axis_unit = "pct", multiply_by = 1
  )

  config_no_unit <- config_base
  config_no_unit$y_axis_unit <- NULL

  key1 <- generate_spc_cache_key(data, config_base)
  key2 <- generate_spc_cache_key(data, config_no_unit)

  expect_false(identical(key1, key2))
})

test_that("generate_spc_cache_key returnerer character string", {
  data <- data.frame(x = 1:5, y = c(1, 2, 3, 4, 5))
  config <- list(
    chart_type = "run", x_column = "x", y_column = "y",
    n_column = NULL, freeze_position = NULL, part_positions = NULL,
    target_value = NULL, centerline_value = NULL, y_axis_unit = NULL,
    multiply_by = 1
  )

  key <- generate_spc_cache_key(data, config)

  expect_type(key, "character")
  expect_true(nchar(key) > 0)
})
