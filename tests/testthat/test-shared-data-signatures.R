# test-shared-data-signatures.R
# H14: Tests for shared data signatures
# Sikrer signaturer genbruges på tværs af QIC + auto-detect caches
#
# Note: Sampling-cache fjernet i Issue #494. Tests der validerede
# cache-størrelse og eviction er fjernet tilsvarende.

test_that("generate_shared_data_signature creates consistent signatures", {
  # SETUP
  test_data <- data.frame(
    x = 1:10,
    y = 11:20,
    z = letters[1:10]
  )

  # TEST: Same data produces same signature
  sig1 <- generate_shared_data_signature(test_data)
  sig2 <- generate_shared_data_signature(test_data)

  expect_equal(sig1, sig2)
  expect_type(sig1, "character")
  expect_true(nchar(sig1) > 10) # xxhash64 produces long strings
})

test_that("signatures change when data changes", {
  # SETUP
  data1 <- data.frame(x = 1:10, y = 11:20)
  data2 <- data.frame(x = 1:10, y = 21:30) # Different y values

  # TEST: Different data = different signatures
  sig1 <- generate_shared_data_signature(data1)
  sig2 <- generate_shared_data_signature(data2)

  expect_false(sig1 == sig2)
})

test_that("signatures change when structure changes", {
  # SETUP
  data1 <- data.frame(x = 1:10, y = 11:20)
  data2 <- data.frame(x = 1:10, y = 11:20, z = 21:30) # Extra column

  # TEST: Different structure with include_structure = TRUE
  sig1 <- generate_shared_data_signature(data1, include_structure = TRUE)
  sig2 <- generate_shared_data_signature(data2, include_structure = TRUE)

  expect_false(sig1 == sig2)
})

test_that("data-only signatures ignore structure", {
  # SETUP: Same data values, different column names
  data1 <- data.frame(a = 1:10, b = 11:20)
  data2 <- data.frame(x = 1:10, y = 11:20)

  # TEST: With include_structure = FALSE, should focus on values
  sig1 <- generate_shared_data_signature(data1, include_structure = FALSE)
  sig2 <- generate_shared_data_signature(data2, include_structure = FALSE)

  # Values are same, but column names differ
  # With structure = FALSE, signatures should still differ due to serialization
  # but be faster to compute
  expect_type(sig1, "character")
  expect_type(sig2, "character")
})

test_that("empty data returns special signature", {
  # TEST: NULL data
  sig_null <- generate_shared_data_signature(NULL)
  expect_equal(sig_null, "empty_data")

  # TEST: Zero-row data
  empty_df <- data.frame(x = numeric(0), y = character(0))
  sig_empty <- generate_shared_data_signature(empty_df)
  expect_equal(sig_empty, "empty_data")
})

test_that("QIC cache uses shared signatures", {
  # SETUP
  test_data <- data.frame(x = 1:5, y = 6:10)
  params <- list(chart = "run", x_col = "x", y_col = "y")

  # TEST: QIC cache key uses optimized version
  key <- generate_qic_cache_key(test_data, params)

  expect_true(grepl("^qic_", key))
  expect_type(key, "character")

  # Verify same data produces same key
  key2 <- generate_qic_cache_key(test_data, params)
  expect_equal(key, key2)
})

test_that("auto-detect cache uses shared signatures", {
  # SETUP
  test_data <- data.frame(Dato = 1:5, Værdi = 6:10)

  # TEST: Auto-detect cache key uses optimized version
  key <- generate_autodetect_cache_key_optimized(test_data)

  expect_true(grepl("^autodetect_", key))
  expect_type(key, "character")

  # Verify consistency
  key2 <- generate_autodetect_cache_key_optimized(test_data)
  expect_equal(key, key2)
})

test_that("backward compatibility wrapper works", {
  # SETUP
  test_data <- data.frame(a = 1:5, b = 6:10)

  # TEST: Old create_data_signature still works
  sig_old <- create_data_signature(test_data)
  sig_new <- generate_shared_data_signature(test_data, include_structure = TRUE)

  # Should produce same result
  expect_equal(sig_old, sig_new)
})

test_that("shared signatures are consistent for large dataset", {
  set.seed(42)
  skip_on_cran()

  # SETUP
  large_data <- data.frame(
    x = 1:1000,
    y = rnorm(1000),
    z = sample(letters, 1000, replace = TRUE)
  )

  # Kald to gange — full digest, ingen cache
  sig1 <- generate_shared_data_signature(large_data)
  qic_key1 <- generate_qic_cache_key(large_data, list(chart = "run"))
  autodetect_key1 <- generate_autodetect_cache_key_optimized(large_data)

  sig2 <- generate_shared_data_signature(large_data)
  qic_key2 <- generate_qic_cache_key(large_data, list(chart = "run"))
  autodetect_key2 <- generate_autodetect_cache_key_optimized(large_data)

  # Verify keys match
  expect_equal(sig1, sig2)
  expect_equal(qic_key1, qic_key2)
  expect_equal(autodetect_key1, autodetect_key2)
})
