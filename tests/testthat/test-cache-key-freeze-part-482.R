# test-cache-key-freeze-part-482.R
# Regression-tests for #482: build_cache_key + generate_spc_cache_key skal
# differentiere paa freeze_column, part_column, cl_column og kommentar_column.
# Foer fix returnerede cachen stale chart ved freeze/part-toggle, hvilket
# kunne flippe baseline-fortolkning klinisk.

test_that("generate_spc_cache_key differentierer paa freeze_column", {
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13),
    Frys = c(rep(TRUE, 5), rep(FALSE, 5)),
    Frys_alt = c(rep(TRUE, 3), rep(FALSE, 7))
  )

  base_config <- list(
    chart_type = "i", x_column = "Dato", y_column = "Vaerdi",
    n_column = NULL, target_value = NULL, centerline_value = NULL,
    y_axis_unit = NULL, multiply_by = 1
  )

  key_no_freeze <- generate_spc_cache_key(data, base_config)
  key_freeze1 <- generate_spc_cache_key(data, c(base_config, list(freeze_column = "Frys")))
  key_freeze2 <- generate_spc_cache_key(data, c(base_config, list(freeze_column = "Frys_alt")))

  expect_false(identical(key_no_freeze, key_freeze1))
  expect_false(identical(key_freeze1, key_freeze2))
})

test_that("generate_spc_cache_key differentierer paa part_column", {
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13),
    Fase = c(rep("a", 5), rep("b", 5)),
    Fase_alt = c(rep("x", 3), rep("y", 7))
  )

  base_config <- list(
    chart_type = "i", x_column = "Dato", y_column = "Vaerdi",
    n_column = NULL, target_value = NULL, centerline_value = NULL,
    y_axis_unit = NULL, multiply_by = 1
  )

  key_no_part <- generate_spc_cache_key(data, base_config)
  key_part1 <- generate_spc_cache_key(data, c(base_config, list(part_column = "Fase")))
  key_part2 <- generate_spc_cache_key(data, c(base_config, list(part_column = "Fase_alt")))

  expect_false(identical(key_no_part, key_part1))
  expect_false(identical(key_part1, key_part2))
})

test_that("generate_spc_cache_key differentierer paa cl_column", {
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13),
    CL = rep(12, 10),
    CL_alt = rep(13, 10)
  )

  base_config <- list(
    chart_type = "i", x_column = "Dato", y_column = "Vaerdi",
    n_column = NULL, target_value = NULL, centerline_value = NULL,
    y_axis_unit = NULL, multiply_by = 1
  )

  key_no_cl <- generate_spc_cache_key(data, base_config)
  key_cl1 <- generate_spc_cache_key(data, c(base_config, list(cl_column = "CL")))
  key_cl2 <- generate_spc_cache_key(data, c(base_config, list(cl_column = "CL_alt")))

  expect_false(identical(key_no_cl, key_cl1))
  expect_false(identical(key_cl1, key_cl2))
})

test_that("generate_spc_cache_key differentierer paa kommentar_column-data", {
  # NOTE: data ses kun via 3-row-sampling i generate_shared_data_signature
  # (first/middle/last); aendringer skal ramme et af disse positioner for at
  # trigge cache-miss. Separat hash-collision-bug i 3-row sampling er kendt
  # — dette test verificerer kun at kommentar_column inkluderes i data-subsettet.
  data1 <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13),
    Kommentar = c("a", rep(NA, 9))
  )
  data2 <- data1
  # Aendrer first row (position 1) for at sikre data_ptr-cache-miss
  data2$Kommentar[1] <- "b"

  config <- list(
    chart_type = "i", x_column = "Dato", y_column = "Vaerdi",
    n_column = NULL, kommentar_column = "Kommentar",
    target_value = NULL, centerline_value = NULL,
    y_axis_unit = NULL, multiply_by = 1
  )

  key1 <- generate_spc_cache_key(data1, config)
  key2 <- generate_spc_cache_key(data2, config)

  expect_false(identical(key1, key2))
})

test_that("build_cache_key differentierer paa freeze_var/part_var/cl_var/notes_column", {
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13),
    Frys = c(rep(TRUE, 5), rep(FALSE, 5)),
    Fase = c(rep("a", 5), rep("b", 5)),
    CL = rep(12, 10),
    Note = c("a", rep(NA, 9))
  )

  base_args <- list(
    data = data, chart_type = "i", x_var = "Dato", y_var = "Vaerdi",
    n_var = NULL, multiply = 1, extra_params = list(), use_cache = TRUE
  )

  key_baseline <- do.call(build_cache_key, base_args)
  key_freeze <- do.call(build_cache_key, c(base_args, list(freeze_var = "Frys")))
  key_part <- do.call(build_cache_key, c(base_args, list(part_var = "Fase")))
  key_cl <- do.call(build_cache_key, c(base_args, list(cl_var = "CL")))
  key_notes <- do.call(build_cache_key, c(base_args, list(notes_column = "Note")))

  expect_false(identical(key_baseline, key_freeze))
  expect_false(identical(key_baseline, key_part))
  expect_false(identical(key_baseline, key_cl))
  expect_false(identical(key_baseline, key_notes))

  # Identiske kald -> deterministisk
  key_freeze_2 <- do.call(build_cache_key, c(base_args, list(freeze_var = "Frys")))
  expect_identical(key_freeze, key_freeze_2)
})

test_that("build_cache_key respekterer use_cache=FALSE", {
  expect_null(build_cache_key(
    data = data.frame(x = 1:3, y = 1:3),
    chart_type = "run", x_var = "x", y_var = "y", n_var = NULL,
    use_cache = FALSE
  ))
})
