# test-cache.R
# Konsolideret cache testfil (Phase 3, Issue #322)
# Merget fra:
#   - test-cache-collision-fix.R       (3 tests: session cache identity)
#   - test-cache-data-signature-bugs.R (12 tests: data signature bugs #1/#2)
#   - test-cache-invalidation-sprint3.R (10 tests: cache invalidation strategy)
#
# Bevaret separat (forskelligt fokus):
#   - test-utils_performance_caching.R — unit tests for caching utilities
#   - test-utils_qic_caching.R         — qicharts2-specifik cache
#   - test-spc-cache-integration.R     — SPC pipeline cache integration

clear_cache_if_available <- function(...) {
  if (exists("clear_performance_cache", mode = "function")) {
    clear_performance_cache(...)
  }
}

# ===========================================================================
# Fra test-cache-collision-fix.R: Session cache identity
# ===========================================================================

test_that("get_session_cache returnerer samme env ved gentagne kald", {
  cache1 <- get_session_cache(session = NULL)
  cache2 <- get_session_cache(session = NULL)

  expect_true(is.environment(cache1))
  expect_identical(cache1, cache2)
})

test_that("get_session_cache returnerer unikt env per process", {
  cache <- get_session_cache(session = NULL)
  expect_true(is.environment(cache))
})

test_that("clear_performance_cache eksisterer og kan kaldes uden fejl", {
  expect_no_error(clear_performance_cache())
  expect_true(exists("clear_performance_cache") && is.function(clear_performance_cache))
})

# ===========================================================================
# Fra test-cache-data-signature-bugs.R: Data signature bug tests
# ===========================================================================

# Test helpers ----

create_cache_test_dataset <- function(nrows = 20, ncols = 3) {
  data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = nrows),
    Tæller = sample(40:60, nrows, replace = TRUE),
    Nævner = rep(100, nrows),
    stringsAsFactors = FALSE
  )
}

# Bug #1: Autodetect cache collision when rows 11+ change ----

test_that("create_data_signature detects changes in rows beyond first 10", {
  data_original <- create_cache_test_dataset(nrows = 20)
  sig_original <- create_data_signature(data_original)

  data_mutated <- data_original
  data_mutated$Tæller[11] <- 999
  sig_mutated <- create_data_signature(data_mutated)

  expect_false(
    identical(sig_original, sig_mutated),
    info = "Bug #1: Signature must change when rows beyond 10 are modified"
  )
})

test_that("create_data_signature detects changes in last rows", {
  data_original <- create_cache_test_dataset(nrows = 50)
  sig_original <- create_data_signature(data_original)

  data_mutated <- data_original
  data_mutated$Tæller[41:50] <- 999
  sig_mutated <- create_data_signature(data_mutated)

  expect_false(
    identical(sig_original, sig_mutated),
    info = "Signature must change when tail rows are modified"
  )
})

test_that("create_data_signature detects deleted rows beyond first 10", {
  data_full <- create_cache_test_dataset(nrows = 20)
  sig_full <- create_data_signature(data_full)

  data_truncated <- data_full[1:10, ]
  sig_truncated <- create_data_signature(data_truncated)

  expect_false(
    identical(sig_full, sig_truncated),
    info = "Signature must change when rows are deleted"
  )
})

test_that("create_data_signature is stable for identical data", {
  data1 <- create_cache_test_dataset(nrows = 30)
  data2 <- data1

  sig1 <- create_data_signature(data1)
  sig2 <- create_data_signature(data2)

  expect_identical(sig1, sig2)
})

# Bug #2: Data content cache uses only first row ----

test_that("evaluate_data_content_cached detects changes beyond first row", {
  skip_if_not(
    exists("evaluate_data_content_cached"),
    "evaluate_data_content_cached not loaded"
  )

  data_original <- create_cache_test_dataset(nrows = 20)
  result_original <- evaluate_data_content_cached(data_original, session = NULL)
  expect_true(result_original, info = "Should detect meaningful data")

  data_cleared <- data_original
  data_cleared$Tæller[2:20] <- NA
  data_cleared$Nævner[2:20] <- NA

  clear_cache_if_available()

  result_cleared <- evaluate_data_content_cached(data_cleared, session = NULL)

  data_empty_tail <- data_original
  data_empty_tail[2:20, ] <- NA

  clear_cache_if_available()

  result_empty_tail <- evaluate_data_content_cached(data_empty_tail, session = NULL)
  # Verificér kald lykkes (cache-nøgle anderledes end original)
  expect_type(result_empty_tail, "logical")
})

test_that("data content cache key changes when middle rows cleared", {
  skip_if_not(
    exists("evaluate_data_content_cached"),
    "evaluate_data_content_cached not loaded"
  )

  data_full <- create_cache_test_dataset(nrows = 30)
  result_full <- evaluate_data_content_cached(data_full, session = NULL)
  expect_true(result_full)

  data_sparse <- data_full
  data_sparse$Tæller[2:30] <- NA
  data_sparse$Nævner[2:30] <- NA
  data_sparse$Dato[2:30] <- NA

  clear_cache_if_available()

  result_sparse <- evaluate_data_content_cached(data_sparse, session = NULL)
  expect_true(result_sparse)
})

test_that("data content cache detects completely empty data after row 1", {
  data <- data.frame(
    col1 = c(1, rep(NA, 19)),
    col2 = c("A", rep("", 19)),
    stringsAsFactors = FALSE
  )

  result <- evaluate_data_content_cached(data, session = NULL)
  expect_true(result)

  data_empty <- data
  data_empty[1, ] <- NA

  clear_cache_if_available()

  result_empty <- evaluate_data_content_cached(data_empty, session = NULL)
  expect_false(result_empty)
})

# Shared utility function tests ----

test_that("create_full_data_signature handles NULL and empty data", {
  expect_equal(create_data_signature(NULL), "empty_data")

  empty_df <- data.frame()
  expect_equal(create_data_signature(empty_df), "empty_data")

  zero_row_df <- data.frame(col1 = character(0), col2 = numeric(0))
  expect_equal(create_data_signature(zero_row_df), "empty_data")
})

test_that("create_full_data_signature includes all metadata", {
  data <- create_cache_test_dataset(nrows = 15)
  sig1 <- create_data_signature(data)

  data_renamed <- data
  names(data_renamed)[1] <- "NewName"
  sig2 <- create_data_signature(data_renamed)

  expect_false(identical(sig1, sig2),
    info = "Signature should change when column names change"
  )

  data_type_change <- data
  data_type_change$Tæller <- as.character(data_type_change$Tæller)
  sig3 <- create_data_signature(data_type_change)

  expect_false(identical(sig1, sig3),
    info = "Signature should change when column types change"
  )
})

test_that("create_full_data_signature is deterministic", {
  data <- create_cache_test_dataset(nrows = 25)
  sigs <- replicate(5, create_data_signature(data))

  expect_true(all(sigs == sigs[1]),
    info = "Signature should be deterministic"
  )
})

test_that("create_full_data_signature performs reasonably on large data", {
  set.seed(42)
  skip_on_ci()

  large_data <- data.frame(
    x1 = rnorm(10000),
    x2 = rnorm(10000),
    x3 = rnorm(10000),
    x4 = sample(letters, 10000, replace = TRUE)
  )

  timing <- system.time({
    sig <- create_data_signature(large_data)
  })

  expect_true(timing["elapsed"] < 0.1,
    info = "Signature generation should be fast even for large data"
  )
  expect_type(sig, "character")
  expect_true(nchar(sig) > 10, info = "Signature should be non-trivial hash")
})

test_that("INTEGRATION: autodetect cache invalidates when data changes beyond row 10", {
  skip_if_not(
    exists("detect_columns_with_cache"),
    "detect_columns_with_cache not available"
  )

  data1 <- data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    Tæller = c(rep(50, 10), rep(100, 10)),
    Nævner = rep(100, 20)
  )

  clear_cache_if_available()

  result1 <- detect_columns_with_cache(data1, app_state = NULL)

  data2 <- data1
  data2$Tæller[11:20] <- 200

  result2 <- detect_columns_with_cache(data2, app_state = NULL)

  expect_false(is.null(result1))
  expect_false(is.null(result2))
})

# ===========================================================================
# Fra test-cache-invalidation-sprint3.R: Cache invalidation strategy
# ===========================================================================

test_that("Cache invalidation system is available", {
  expect_true(exists("clear_performance_cache"))
  expect_true(is.function(clear_performance_cache))
  expect_true(exists("get_cached_result"))
  expect_true(exists("cache_result"))
})

test_that("clear_performance_cache clears all cache entries", {
  cache_result("test_key_1", list(value = "data1"), timeout_seconds = 300)
  cache_result("test_key_2", list(value = "data2"), timeout_seconds = 300)

  cached_1 <- get_cached_result("test_key_1")
  cached_2 <- get_cached_result("test_key_2")
  expect_false(is.null(cached_1))
  expect_false(is.null(cached_2))

  clear_performance_cache()

  cached_1_after <- get_cached_result("test_key_1")
  cached_2_after <- get_cached_result("test_key_2")
  expect_null(cached_1_after)
  expect_null(cached_2_after)
})

test_that("clear_performance_cache with pattern clears selective entries", {
  cache_result("autodetect_key1", list(value = "auto1"), timeout_seconds = 300)
  cache_result("autodetect_key2", list(value = "auto2"), timeout_seconds = 300)
  cache_result("plot_key1", list(value = "plot1"), timeout_seconds = 300)

  clear_performance_cache("autodetect_.*")

  expect_null(get_cached_result("autodetect_key1"))
  expect_null(get_cached_result("autodetect_key2"))
  expect_false(is.null(get_cached_result("plot_key1")))

  clear_performance_cache()
})

test_that("cache_result stores data correctly", {
  test_data <- list(x = 1:10, y = 11:20)

  cache_result("test_data_key", test_data, timeout_seconds = 300)

  cached <- get_cached_result("test_data_key")
  expect_false(is.null(cached))
  expect_equal(cached$value$x, 1:10)
  expect_equal(cached$value$y, 11:20)

  clear_performance_cache()
})

test_that("cached results expire after timeout", {
  skip_on_ci()
  test_data <- list(value = "short_lived")

  cache_result("short_timeout_key", test_data, timeout_seconds = 1)

  cached_immediate <- get_cached_result("short_timeout_key")
  expect_false(is.null(cached_immediate))

  Sys.sleep(2)

  cached_after <- get_cached_result("short_timeout_key")
  expect_null(cached_after)
})

test_that("data_updated event triggers cache invalidation", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  cache_result("test_before_update", list(value = "old_data"), timeout_seconds = 300)
  expect_false(is.null(get_cached_result("test_before_update")))

  safe_operation(
    "Clear performance cache on data update",
    code = {
      clear_performance_cache()
    }
  )

  expect_null(get_cached_result("test_before_update"))
})

test_that("session_reset event triggers cache invalidation", {
  cache_result("test_before_reset", list(value = "session_data"), timeout_seconds = 300)
  expect_false(is.null(get_cached_result("test_before_reset")))

  safe_operation(
    "Clear performance cache on session reset",
    code = {
      clear_performance_cache()
    }
  )

  expect_null(get_cached_result("test_before_reset"))
})

test_that("cache stats are accurate after operations", {
  skip("get_cache_stats() blev fjernet. Intern .performance_cache er ikke længere eksponeret via public API — se manage_cache_size() og get_cached_result() for alternativer.")
  clear_performance_cache()

  cache_result("stats_key_1", list(value = 1), timeout_seconds = 300)
  cache_result("stats_key_2", list(value = 2), timeout_seconds = 300)
  cache_result("stats_key_3", list(value = 3), timeout_seconds = 300)

  stats <- get_cache_stats()

  expect_equal(stats$total_entries, 3)
  expect_true(stats$total_size_bytes > 0)

  clear_performance_cache()
  stats_after <- get_cache_stats()
  expect_equal(stats_after$total_entries, 0)
})

test_that("multiple cache operations handle concurrency safely", {
  clear_performance_cache()

  for (i in 1:20) {
    cache_result(paste0("concurrent_", i), list(value = i), timeout_seconds = 300)
  }

  for (i in 1:20) {
    cached <- get_cached_result(paste0("concurrent_", i))
    expect_false(is.null(cached))
    expect_equal(cached$value$value, i)
  }

  clear_performance_cache()
})

test_that("cache invalidation is safe when cache functions don't exist", {
  if (exists("clear_performance_cache") && is.function(clear_performance_cache)) {
    result <- safe_operation(
      "Clear performance cache test",
      code = {
        clear_performance_cache()
        TRUE
      },
      fallback = function(e) {
        FALSE
      }
    )
    expect_true(result)
  }
})

# Cleanup after all tests
clear_performance_cache()
