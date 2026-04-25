# Tests for utils_qic_caching.R

# create_qic_cache() ---------------------------------------------------------

test_that("create_qic_cache returnerer korrekt interface", {
  cache <- create_qic_cache()
  expect_type(cache, "list")
  expect_true(all(c("get", "set", "clear", "size", "stats") %in% names(cache)))
})

test_that("create_qic_cache starter tom", {
  cache <- create_qic_cache()
  expect_equal(cache$size(), 0)
})

test_that("create_qic_cache set og get virker", {
  cache <- create_qic_cache()
  cache$set("key1", list(result = 42), timeout = 3600)
  result <- cache$get("key1")
  expect_equal(result$result, 42)
})

test_that("create_qic_cache get returnerer NULL for manglende key", {
  cache <- create_qic_cache()
  expect_null(cache$get("nonexistent"))
})

test_that("create_qic_cache clear tømmer alle entries", {
  cache <- create_qic_cache()
  cache$set("key1", "value1", timeout = 3600)
  cache$set("key2", "value2", timeout = 3600)
  expect_equal(cache$size(), 2)

  cache$clear()
  expect_equal(cache$size(), 0)
})

test_that("create_qic_cache stats tracker hits og misses", {
  cache <- create_qic_cache()
  cache$set("key1", "value1", timeout = 3600)

  cache$get("key1") # Hit
  cache$get("key1") # Hit
  cache$get("missing") # Miss

  stats <- cache$stats()
  expect_equal(stats$hits, 2)
  expect_equal(stats$misses, 1)
})

test_that("create_qic_cache respekterer max_size", {
  cache <- create_qic_cache(max_size = 3)

  for (i in 1:5) {
    cache$set(paste0("key", i), paste0("val", i), timeout = 3600)
  }

  # Cache størrelse bør ikke overstige max_size

  expect_lte(cache$size(), 3)
})

# generate_qic_cache_key() ----------------------------------------------------

test_that("generate_qic_cache_key returnerer konsistent key", {
  df <- data.frame(x = 1:10)
  params <- list(chart_type = "run")

  key1 <- generate_qic_cache_key(df, params)
  key2 <- generate_qic_cache_key(df, params)
  expect_equal(key1, key2)
})

test_that("generate_qic_cache_key giver forskellige keys for forskellige data", {
  params <- list(chart_type = "run")
  key1 <- generate_qic_cache_key(data.frame(x = 1:10), params)
  key2 <- generate_qic_cache_key(data.frame(x = 11:20), params)
  expect_false(key1 == key2)
})

test_that("generate_qic_cache_key giver forskellige keys for forskellige params", {
  df <- data.frame(x = 1:10)
  key1 <- generate_qic_cache_key(df, list(chart_type = "run"))
  key2 <- generate_qic_cache_key(df, list(chart_type = "i"))
  expect_false(key1 == key2)
})

test_that("generate_qic_cache_key starter med qic_ prefix", {
  key <- generate_qic_cache_key(data.frame(x = 1), list(type = "run"))
  expect_true(startsWith(key, "qic_"))
})
