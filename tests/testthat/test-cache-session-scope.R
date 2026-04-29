# test-cache-session-scope.R
# Tests for session-scoped cache-isolation
#
# Verificerer at app_state$cache$qic er session-lokal:
# - To separate app_state-instanser deler ikke cache
# - clear() på én cache påvirker ikke en anden
# - Prefix-baseret invalidation virker korrekt

test_that("to app_state-instanser deler ikke qic-cache", {
  app_state_1 <- list(cache = list(qic = NULL))
  app_state_2 <- list(cache = list(qic = NULL))

  cache1 <- get_or_init_qic_cache(app_state_1)
  cache2 <- get_or_init_qic_cache(app_state_2)

  # Sæt en værdi i cache1
  cache1$set("shared_key", list(value = "session1_data"), timeout = 3600)

  # Cache2 bør IKKE indeholde nøglen
  result2 <- cache2$get("shared_key")
  expect_null(result2, info = "Cache fra anden app_state skal være tom")
})

test_that("clear() på én cache påvirker ikke en anden", {
  app_state_a <- list(cache = list(qic = NULL))
  app_state_b <- list(cache = list(qic = NULL))

  cache_a <- get_or_init_qic_cache(app_state_a)
  cache_b <- get_or_init_qic_cache(app_state_b)

  cache_a$set("key_a", list(value = "data_a"), timeout = 3600)
  cache_b$set("key_b", list(value = "data_b"), timeout = 3600)

  # Clear cache_a — cache_b bør forblive intakt
  cache_a$clear()

  expect_null(cache_a$get("key_a"), info = "cache_a skal være tom efter clear()")
  expect_equal(cache_b$get("key_b"), list(value = "data_b"),
    info = "cache_b skal forblive intakt"
  )
})

test_that("qic-cache keys()-metode returnerer alle nøgler", {
  app_state <- list(cache = list(qic = NULL))
  cache <- get_or_init_qic_cache(app_state)
  cache$clear()

  cache$set("spc_run_abc123", list(value = "chart1"), timeout = 3600)
  cache$set("spc_i_def456", list(value = "chart2"), timeout = 3600)

  all_keys <- cache$keys()

  expect_true(is.character(all_keys))
  expect_true("spc_run_abc123" %in% all_keys)
  expect_true("spc_i_def456" %in% all_keys)
  expect_equal(length(all_keys), 2L)
})

test_that("qic-cache prefix-baseret invalidation fjerner kun matchende nøgler", {
  app_state <- list(cache = list(qic = NULL))
  cache <- get_or_init_qic_cache(app_state)
  cache$clear()

  cache$set("spc_run_key1", list(value = "run1"), timeout = 3600)
  cache$set("spc_run_key2", list(value = "run2"), timeout = 3600)
  cache$set("spc_i_key3", list(value = "i1"), timeout = 3600)

  # Invalider kun "run"-poster
  cache$clear_prefix("spc_run_")

  expect_null(cache$get("spc_run_key1"), info = "spc_run_key1 skal fjernes")
  expect_null(cache$get("spc_run_key2"), info = "spc_run_key2 skal fjernes")
  expect_equal(cache$get("spc_i_key3"), list(value = "i1"),
    info = "spc_i_key3 skal forblive intakt"
  )
})

test_that("qic-cache size() er korrekt efter operationer", {
  app_state <- list(cache = list(qic = NULL))
  cache <- get_or_init_qic_cache(app_state)
  cache$clear()

  expect_equal(cache$size(), 0L)

  cache$set("k1", list(v = 1), timeout = 3600)
  cache$set("k2", list(v = 2), timeout = 3600)
  expect_equal(cache$size(), 2L)

  cache$clear_prefix("k1")
  expect_equal(cache$size(), 1L)

  cache$clear()
  expect_equal(cache$size(), 0L)
})
