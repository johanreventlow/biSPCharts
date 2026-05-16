# test-cache-key-reactive-title.R
# Regression-tests for cycle 11 H2-NEW (Codex peer-review 2026-05-16):
# compute_spc_results_bfh() skal resolve chart_title_reactive (Shiny reactive
# function-objekt) FOER cache-key generation. Foer fix blev fn-objektet hashet
# som reference => samme hash trods aendret closed-over state => stale cache
# med gamle titler i analysis-path (utils_server_visualization.R:293).

test_that("compute_spc_results_bfh: post-fix flow producerer vaerdi-baserede cache-keys (cycle 11 H2-NEW)", {
  # Verificerer at facade-resolution-flow giver forskellige cache-keys for
  # forskellige RESOLVED titler. Post-fix: extra_params$chart_title er
  # garanteret string foer build_cache_key kaldes.
  skip_if_not_installed("shiny")

  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
  )

  # Simulér facade-resolution: resolve chart_title_reactive til string,
  # ryd reactive-feltet, byg cache-key (matcher fct_spc_bfh_facade.R:173-194).
  facade_resolve_and_key <- function(reactive_or_string) {
    shiny::isolate({
      extra_params <- list(chart_title_reactive = reactive_or_string)
      extra_params$chart_title <- resolve_bfh_chart_title(
        extra_params$chart_title_reactive %||% extra_params$chart_title
      )
      extra_params$chart_title_reactive <- NULL
      build_cache_key(
        data = data, chart_type = "i", x_var = "Dato", y_var = "Vaerdi",
        n_var = NULL, multiply = 1, use_cache = TRUE,
        extra_params = extra_params
      )
    })
  }

  # Reactive der returnerer "Titel A" vs reactive der returnerer "Titel B"
  rx_a <- shiny::reactive("Titel A")
  rx_b <- shiny::reactive("Titel B")

  key_a <- facade_resolve_and_key(rx_a)
  key_b <- facade_resolve_and_key(rx_b)

  expect_false(identical(key_a, key_b),
    info = "Forskellige resolved titler skal give forskellige cache-keys"
  )

  # Determinisme: samme reactive (samme resolved value) → samme key
  key_a_repeat <- facade_resolve_and_key(rx_a)
  expect_identical(key_a, key_a_repeat,
    info = "Samme resolved value skal give samme key (deterministisk)"
  )

  # String og reactive med samme resolved value → samme key
  key_string_a <- facade_resolve_and_key("Titel A")
  expect_identical(key_a, key_string_a,
    info = "Reactive og string med samme resolved value skal give samme key"
  )
})

test_that("build_cache_key alene resolver IKKE reactives (demonstrerer hvorfor facade-fix er noedvendig)", {
  # Demonstration: build_cache_key passerer raw extra_params til
  # generate_spc_cache_key. Hvis raw reactive sendes ind, hashes
  # function-objektet IKKE den resolved value.
  skip_if_not_installed("shiny")

  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
  )

  # To distinkte reactives med samme returneret value
  rx_a1 <- shiny::reactive("Titel A")
  rx_a2 <- shiny::reactive("Titel A")

  shiny::isolate({
    key_rx1 <- build_cache_key(
      data = data, chart_type = "i", x_var = "Dato", y_var = "Vaerdi",
      n_var = NULL, multiply = 1, use_cache = TRUE,
      extra_params = list(chart_title = rx_a1)
    )
    key_rx2 <- build_cache_key(
      data = data, chart_type = "i", x_var = "Dato", y_var = "Vaerdi",
      n_var = NULL, multiply = 1, use_cache = TRUE,
      extra_params = list(chart_title = rx_a2)
    )
    key_string <- build_cache_key(
      data = data, chart_type = "i", x_var = "Dato", y_var = "Vaerdi",
      n_var = NULL, multiply = 1, use_cache = TRUE,
      extra_params = list(chart_title = "Titel A")
    )
  })

  # To distinkte fn-objekter → forskellige hashes (selv om samme return-value).
  # Demonstrerer at build_cache_key hashes REFERENCE, ej VAERDI.
  expect_false(identical(key_rx1, key_rx2),
    info = "Distinkte fn-objekter giver forskellige hashes - reference-baseret"
  )
  # String-key differer fra fn-keys → bekraefter at fn-input ej resolves.
  expect_false(identical(key_rx1, key_string),
    info = "build_cache_key resolver IKKE reactives (facade skal resolve foerst)"
  )
})

test_that("build_cache_key differentierer korrekt naar chart_title er pre-resolved string", {
  # No-regression: eksisterende string-based test fra
  # test-cache-key-target-text-chart-title.R skal stadig passere.
  data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
  )

  base_args <- list(
    data = data, chart_type = "i", x_var = "Dato", y_var = "Vaerdi",
    n_var = NULL, multiply = 1, use_cache = TRUE
  )

  key_a <- do.call(build_cache_key, c(base_args, list(extra_params = list(chart_title = "A"))))
  key_b <- do.call(build_cache_key, c(base_args, list(extra_params = list(chart_title = "B"))))
  key_a_repeat <- do.call(build_cache_key, c(base_args, list(extra_params = list(chart_title = "A"))))

  expect_false(identical(key_a, key_b))
  expect_identical(key_a, key_a_repeat)
})
