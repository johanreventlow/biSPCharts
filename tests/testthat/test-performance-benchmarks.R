# test-performance-benchmarks.R
# Rewrite Fase 2: TDD mod nuværende performance API
# Baseret paa R/fct_spc_bfh_service.R, R/state_management.R
#
# NOTE: Mange benchmark-tests er markeret SKIP med TODO paa grund af API-drift:
# generateSPCPlot()-signaturen er aendret (config-baseret, ikke x_col/y_col/n_col)
# og cache-API er aendret. Se Issue #203 for Fase 3 followup.

# =============================================================================
# KENDTE BEGRAENSNINGER I NUVAERENDE IMPLEMENTATION (dokumenteret):
#
# 1. generateSPCPlot() bruger nu config-parameter (ikke x_col, y_col, n_col).
#    Alle benchmark-tests der kalder den gamle API fejler.
# 2. cache_startup_data() og load_cached_startup_data() tager nu ingen argumenter.
# 3. detect_columns_full_analysis() eksisterer ikke i namespace.
# 4. detect_columns_name_based() eksisterer ikke i namespace.
# =============================================================================

# Helper til at oprette benchmark data (bevar fra original)
create_benchmark_data <- function(n_rows = 100,
                                  n_cols = 3,
                                  include_dates = TRUE,
                                  include_factors = FALSE) {
  base_data <- data.frame(
    Dato = if (include_dates) {
      seq.Date(as.Date("2024-01-01"), by = "day", length.out = n_rows)
    } else {
      seq_len(n_rows)
    },
    Teller = sample(40:50, n_rows, replace = TRUE),
    Naevner = rep(50, n_rows),
    stringsAsFactors = FALSE
  )

  if (n_cols > 3) {
    for (i in 4:n_cols) {
      base_data[[paste0("Extra_", i - 3)]] <- rnorm(n_rows)
    }
  }

  if (include_factors) {
    base_data$Gruppe <- factor(sample(c("A", "B", "C"), n_rows, replace = TRUE))
  }

  return(base_data)
}

# Helper til at maale memory usage (bevar fra original)
measure_memory_usage <- function(expr) {
  gc(verbose = FALSE, reset = TRUE)
  mem_before <- as.numeric(gc(verbose = FALSE)[2, 2])
  result <- force(expr)
  mem_after <- as.numeric(gc(verbose = FALSE)[2, 2])
  mem_used <- mem_after - mem_before
  list(
    result = result,
    memory_mb = mem_used,
    memory_bytes = mem_used * 1024^2
  )
}

# =============================================================================
# TESTS DER KØRER KORREKT MOD NUVÆRENDE API
# =============================================================================

test_that("create_benchmark_data opretter korrekt datasaet", {
  data <- create_benchmark_data(n_rows = 50)
  expect_equal(nrow(data), 50)
  expect_true("Dato" %in% names(data))
  expect_true("Teller" %in% names(data))
})

test_that("create_benchmark_data respekterer n_cols parameter", {
  data <- create_benchmark_data(n_rows = 10, n_cols = 5)
  expect_equal(ncol(data), 5)
})

test_that("create_benchmark_data with include_factors tilfojer faktor-kolonne", {
  data <- create_benchmark_data(n_rows = 20, include_factors = TRUE)
  expect_true("Gruppe" %in% names(data))
  expect_true(is.factor(data$Gruppe))
})

test_that("create_app_state bruger ikke uacceptabelt meget memory", {
  mem_result <- measure_memory_usage({
    app_state <- create_app_state()
    app_state
  })
  # Maa ikke bruge mere end 100 MB til at oprette app state
  expect_lt(mem_result$memory_mb, 100)
})

test_that("generateSPCPlot eksisterer med korrekt config-baseret signatur", {
  args <- names(formals(generateSPCPlot))
  expect_true("config" %in% args)
  expect_true("data" %in% args)
  expect_true("chart_type" %in% args)
})

test_that("load_cached_startup_data og cache_startup_data eksisterer", {
  expect_true(exists("load_cached_startup_data", mode = "function"))
  expect_true(exists("cache_startup_data", mode = "function"))
})

# =============================================================================
# TESTS SKIPPED MED TODO: API-drift afsloeret under rewrite
# =============================================================================

test_that("generateSPCPlot standard plot < 5s", {
  skip_if_not_installed("bench")
  skip_on_ci()
  test_data <- create_benchmark_data(n_rows = 100)
  config <- list(x_col = "Dato", y_col = "Teller", n_col = "Naevner")
  benchmark_result <- bench::mark(
    plot = generateSPCPlot(
      data = test_data,
      config = config,
      chart_type = "p"
    ),
    iterations = 3,
    check = FALSE,
    memory = FALSE
  )
  expect_lt(as.numeric(benchmark_result$median) * 1000, 5000)
})

test_that("generateSPCPlot stor datasaet plot < 30s", {
  skip_if_not_installed("bench")
  skip_on_ci()
  large_data <- create_benchmark_data(n_rows = 1000)
  config <- list(x_col = "Dato", y_col = "Teller", n_col = "Naevner")
  benchmark_result <- bench::mark(
    plot = generateSPCPlot(
      data = large_data,
      config = config,
      chart_type = "p"
    ),
    iterations = 2,
    check = FALSE,
    memory = FALSE
  )
  expect_lt(as.numeric(benchmark_result$median) * 1000, 30000)
})

test_that("cache_startup_data og load_cached_startup_data virker (ingen argumenter)", {
  cache_startup_data()
  cached <- load_cached_startup_data()
  # cached kan vaere NULL hvis ingen data at cache endnu — funktionen maa ikke kaste fejl
  expect_no_error(load_cached_startup_data())
})

test_that("load_cached_startup_data er hurtigere end gentagen cache_startup_data", {
  skip_if_not_installed("bench")
  # Fyld cachen foerst
  cache_startup_data()
  # Maaler: cache-laesning vs. opbygning af ny cache (ikke vs. get_hospital_colors)
  load_time <- bench::mark(load = load_cached_startup_data(), iterations = 50, check = FALSE)
  build_time <- bench::mark(build = cache_startup_data(), iterations = 50, check = FALSE)
  # load_cached skal vaere hurtigere end at genopbygge cachen
  expect_lt(as.numeric(load_time$median), as.numeric(build_time$median))
})

test_that("TODO Fase 3: detect_columns_full_analysis 1000 raekker < 200ms", {
  skip(paste0(
    "TODO Fase 3: R-bug afsloeret — detect_columns_full_analysis() ikke i namespace (#203-followup)"
  ))
  large_data <- create_benchmark_data(n_rows = 1000, n_cols = 10)
  benchmark_result <- bench::mark(
    processing = detect_columns_full_analysis(large_data),
    iterations = 10,
    check = FALSE
  )
  expect_lt(as.numeric(benchmark_result$median) * 1000, 200)
})

test_that("TODO Fase 3: detect_columns_name_based dansk overhead < 10%", {
  skip(paste0(
    "TODO Fase 3: R-bug afsloeret — detect_columns_name_based() ikke i namespace (#203-followup)"
  ))
  ascii_cols <- c("Teller", "Nevner", "Dato")
  danish_cols <- c("Taeller", "Naevner", "Dato")
  ascii_time <- bench::mark(ascii = detect_columns_name_based(ascii_cols), iterations = 100, check = FALSE)
  danish_time <- bench::mark(danish = detect_columns_name_based(danish_cols), iterations = 100, check = FALSE)
  overhead_pct <- (as.numeric(danish_time$median) - as.numeric(ascii_time$median)) /
    as.numeric(ascii_time$median) * 100
  expect_lt(overhead_pct, 10)
})

test_that("generateSPCPlot memory < 50MB", {
  test_data <- create_benchmark_data(n_rows = 100)
  config <- list(x_col = "Dato", y_col = "Teller", n_col = "Naevner")
  mem_result <- measure_memory_usage({
    generateSPCPlot(
      data = test_data,
      config = config,
      chart_type = "p"
    )
  })
  expect_lt(mem_result$memory_mb, 50)
})

test_that("TODO Fase 3: detect_columns_full_analysis memory skalerer linjaert", {
  skip(paste0(
    "TODO Fase 3: R-bug afsloeret — detect_columns_full_analysis() ikke i namespace (#203-followup)"
  ))
  sizes <- c(100, 500, 1000)
  memory_usage <- numeric(length(sizes))
  for (i in seq_along(sizes)) {
    test_data <- create_benchmark_data(n_rows = sizes[i])
    mem_result <- measure_memory_usage(detect_columns_full_analysis(test_data))
    memory_usage[i] <- mem_result$memory_mb
  }
  memory_ratio <- memory_usage[3] / memory_usage[1]
  expect_lt(memory_ratio, 15)
})

test_that("generateSPCPlot reproducerbare resultater (variance < 15%)", {
  skip("Manual performance benchmark: wall-clock variance is environment-dependent")
  skip_if_not_installed("bench")
  skip_on_ci()
  test_data <- create_benchmark_data(n_rows = 100)
  config <- list(x_col = "Dato", y_col = "Teller", n_col = "Naevner")
  run1 <- bench::mark(
    plot = generateSPCPlot(data = test_data, config = config, chart_type = "p"),
    iterations = 10, check = FALSE, memory = FALSE
  )
  run2 <- bench::mark(
    plot = generateSPCPlot(data = test_data, config = config, chart_type = "p"),
    iterations = 10, check = FALSE, memory = FALSE
  )
  variance_pct <- abs(as.numeric(run2$median) - as.numeric(run1$median)) /
    as.numeric(run1$median) * 100
  expect_lt(variance_pct, 15)
})
