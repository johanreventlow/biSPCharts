# test-cache-key-target-text-chart-title.R
# Regression-tests for backend cache-key #H3 (Codex peer-review 2026-05-08):
# build_cache_key skal differentiere paa target_text og chart_title fordi
# begge bruges i BFH-kald (fct_spc_execute.R:84,86) og paavirker plot-output.
# Foer fix returnerede cachen plot med stale labels naar bruger aendrede
# target-tekst eller chart-titel.

test_that("build_cache_key differentierer paa extra_params$chart_title", {
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
  )

  base_args <- list(
    data = data, chart_type = "i", x_var = "Dato", y_var = "Vaerdi",
    n_var = NULL, multiply = 1, use_cache = TRUE
  )

  key_no_title <- do.call(build_cache_key, c(base_args, list(extra_params = list())))
  key_title_a <- do.call(build_cache_key, c(base_args, list(extra_params = list(chart_title = "Ventetid Q1"))))
  key_title_b <- do.call(build_cache_key, c(base_args, list(extra_params = list(chart_title = "Ventetid Q2"))))

  expect_false(identical(key_no_title, key_title_a))
  expect_false(identical(key_title_a, key_title_b))

  # Identiske kald -> deterministisk
  key_title_a_repeat <- do.call(build_cache_key, c(base_args, list(extra_params = list(chart_title = "Ventetid Q1"))))
  expect_identical(key_title_a, key_title_a_repeat)
})

test_that("build_cache_key differentierer paa extra_params$target_text", {
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
  )

  base_args <- list(
    data = data, chart_type = "i", x_var = "Dato", y_var = "Vaerdi",
    n_var = NULL, multiply = 1, use_cache = TRUE
  )

  ep_no_text <- list(target_value = 12)
  ep_text_a <- list(target_value = 12, target_text = "Maal: 12")
  ep_text_b <- list(target_value = 12, target_text = "Maximum")

  key_no_text <- do.call(build_cache_key, c(base_args, list(extra_params = ep_no_text)))
  key_text_a <- do.call(build_cache_key, c(base_args, list(extra_params = ep_text_a)))
  key_text_b <- do.call(build_cache_key, c(base_args, list(extra_params = ep_text_b)))

  expect_false(identical(key_no_text, key_text_a))
  expect_false(identical(key_text_a, key_text_b))

  # Identiske kald -> deterministisk
  key_text_a_repeat <- do.call(build_cache_key, c(base_args, list(extra_params = ep_text_a)))
  expect_identical(key_text_a, key_text_a_repeat)
})

test_that("build_cache_key behandler chart_title og target_text uafhaengigt", {
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
  )

  base_args <- list(
    data = data, chart_type = "i", x_var = "Dato", y_var = "Vaerdi",
    n_var = NULL, multiply = 1, use_cache = TRUE
  )

  # Forskellig kombination af chart_title + target_text giver forskellige keys
  key_combo_1 <- do.call(build_cache_key, c(base_args, list(
    extra_params = list(chart_title = "A", target_text = "X")
  )))
  key_combo_2 <- do.call(build_cache_key, c(base_args, list(
    extra_params = list(chart_title = "B", target_text = "X")
  )))
  key_combo_3 <- do.call(build_cache_key, c(base_args, list(
    extra_params = list(chart_title = "A", target_text = "Y")
  )))

  expect_false(identical(key_combo_1, key_combo_2))
  expect_false(identical(key_combo_1, key_combo_3))
  expect_false(identical(key_combo_2, key_combo_3))
})
