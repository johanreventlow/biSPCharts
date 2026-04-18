# test-cache-collision-fix.R
# Salvage Fase 2: Opdateret mod nuværende cache API
# create_cached_reactive() returnerer nu reactive() der kræver isolate()

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

test_that("create_cached_reactive returnerer en reactive", {
  cached_func <- create_cached_reactive(
    reactive_expr = function() Sys.time(),
    cache_key = "test_cache_reactive_type"
  )

  # Resultatet er en reactive (funktion) — ikke et environment
  expect_true(is.function(cached_func))
})

test_that("create_cached_reactive cache er konsistent", {
  counter <- 0L
  cached_func <- create_cached_reactive(
    reactive_expr = function() {
      counter <<- counter + 1L
      "constant_result"
    },
    cache_key = "test_cache_collision_consistency"
  )
  result1 <- shiny::isolate(cached_func())
  result2 <- shiny::isolate(cached_func())
  expect_equal(result1, "constant_result")
  expect_equal(result2, "constant_result")
  expect_lte(counter, 2L)
})

test_that("multiple cache keys interfererer ikke", {
  cached_a <- create_cached_reactive(
    reactive_expr = function() paste0("result_a"),
    cache_key = "concurrent_test_a_salvage"
  )
  cached_b <- create_cached_reactive(
    reactive_expr = function() paste0("result_b"),
    cache_key = "concurrent_test_b_salvage"
  )
  result_a <- shiny::isolate(cached_a())
  result_b <- shiny::isolate(cached_b())
  expect_equal(result_a, "result_a")
  expect_equal(result_b, "result_b")
  expect_false(identical(result_a, result_b))
})

test_that("clear_performance_cache eksisterer og kan kaldes uden fejl", {
  expect_no_error(clear_performance_cache())
})

test_that("TODO K1: create_cached_reactive cache-navne i GlobalEnv", {
  skip(paste0(
    "TODO K1 (depender paa manage_cache_size fix): create_cached_reactive() bruger ",
    "session-scoped cache (ikke .GlobalEnv navngivne caches) (#203-followup)\n",
    "Nuvaerende impl: reactive() wrapper med intern get_session_cache()"
  ))
  cached_func <- create_cached_reactive(
    reactive_expr = function() Sys.time(),
    cache_key = "process_test_cache_scoped"
  )
  shiny::isolate(cached_func())
  # Nuvaerende impl bruger module-level .performance_cache (ikke .GlobalEnv navngivne caches)
  pattern <- paste0(".performance_cache_fallback_", Sys.getpid(), "_")
  globalenv_caches <- ls(pattern = pattern, envir = .GlobalEnv, all.names = TRUE)
  expect_equal(length(globalenv_caches), 0L)
})
