# test-cache-collision-fix.R

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
})
