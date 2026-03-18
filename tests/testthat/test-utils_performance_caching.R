# Tests for utils_performance_caching.R

# generate_data_cache_key() ---------------------------------------------------

test_that("generate_data_cache_key returnerer konsistent key for samme data", {
  df <- data.frame(x = 1:10, y = 11:20)
  key1 <- generate_data_cache_key(df, "test")
  key2 <- generate_data_cache_key(df, "test")
  expect_equal(key1, key2)
})

test_that("generate_data_cache_key bruger prefix", {
  df <- data.frame(x = 1:5)
  key <- generate_data_cache_key(df, "autodetect")
  expect_true(startsWith(key, "autodetect_"))
})

test_that("generate_data_cache_key giver forskellige keys for forskellige data", {
  df1 <- data.frame(x = 1:10)
  df2 <- data.frame(x = 11:20)
  key1 <- generate_data_cache_key(df1, "test")
  key2 <- generate_data_cache_key(df2, "test")
  expect_false(key1 == key2)
})

test_that("generate_data_cache_key håndterer NULL og tom data", {
  expect_equal(generate_data_cache_key(NULL, "test"), "test_empty")
  expect_equal(generate_data_cache_key(list(), "test"), "test_empty")
})

test_that("generate_data_cache_key inkluderer structure info", {
  df <- data.frame(x = 1:5, y = 6:10)
  key <- generate_data_cache_key(df, "data")
  # Bør indeholde dimensioner (5x2)
  expect_true(grepl("5x2", key))
})

test_that("generate_data_cache_key med include_names giver anden key", {
  df <- data.frame(x = 1:5, y = 6:10)
  key_without <- generate_data_cache_key(df, "test", include_names = FALSE)
  key_with <- generate_data_cache_key(df, "test", include_names = TRUE)
  expect_false(key_without == key_with)
})

# get_cached_result() og cache_result() ---------------------------------------

test_that("cache_result og get_cached_result round-trips korrekt", {
  # Clear cache først
  clear_performance_cache()

  cache_result("test_key_123", list(value = 42), timeout_seconds = 3600)
  result <- get_cached_result("test_key_123")
  expect_equal(result$value, 42)

  # Cleanup
  clear_performance_cache()
})

test_that("get_cached_result returnerer NULL for manglende key", {
  clear_performance_cache()
  expect_null(get_cached_result("nonexistent_key_xyz"))
})

# clear_performance_cache() ---------------------------------------------------

test_that("clear_performance_cache rydder alle entries", {
  cache_result("temp_key_1", "val1", timeout_seconds = 3600)
  cache_result("temp_key_2", "val2", timeout_seconds = 3600)

  clear_performance_cache()

  expect_null(get_cached_result("temp_key_1"))
  expect_null(get_cached_result("temp_key_2"))
})
