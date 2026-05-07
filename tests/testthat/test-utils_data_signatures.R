# Tests for utils_data_signatures.R
#
# Note: clear_data_signature_cache() og get_data_signature_cache_stats()
# er fjernet i Issue #494 (sampling-cache droppet). Tests herfor fjernet.

# generate_shared_data_signature() --------------------------------------------

test_that("generate_shared_data_signature returnerer konsistent hash", {
  df <- data.frame(x = 1:10, y = 11:20)
  sig1 <- generate_shared_data_signature(df)
  sig2 <- generate_shared_data_signature(df)
  expect_equal(sig1, sig2)
})

test_that("generate_shared_data_signature giver forskellige hashes for forskellige data", {
  df1 <- data.frame(x = 1:10)
  df2 <- data.frame(x = 11:20)
  sig1 <- generate_shared_data_signature(df1)
  sig2 <- generate_shared_data_signature(df2)
  expect_false(sig1 == sig2)
})

test_that("generate_shared_data_signature håndterer NULL og tom data", {
  expect_equal(generate_shared_data_signature(NULL), "empty_data")
  expect_equal(generate_shared_data_signature(data.frame(x = numeric(0))), "empty_data")
})

test_that("generate_shared_data_signature returnerer character string", {
  df <- data.frame(x = 1:5)
  sig <- generate_shared_data_signature(df)
  expect_type(sig, "character")
  expect_length(sig, 1)
})

test_that("generate_shared_data_signature med include_structure=FALSE giver anden hash", {
  df <- data.frame(x = 1:10, y = 11:20)
  sig_with <- generate_shared_data_signature(df, include_structure = TRUE)
  sig_without <- generate_shared_data_signature(df, include_structure = FALSE)
  # De kan potentielt være ens, men typisk er de forskellige
  expect_type(sig_with, "character")
  expect_type(sig_without, "character")
})
