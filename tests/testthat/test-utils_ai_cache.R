# test-utils_ai_cache.R
# Unit tests for AI response caching system (Task #74)

# Test helper: Create mock Shiny session
# Must properly support reactiveVal for session$userData$ai_cache
create_mock_session <- function() {
  # Create environment (not list) for proper by-reference behavior
  session <- new.env(parent = emptyenv())

  session$token <- paste0("session_", as.character(runif(1)))
  session$userData <- new.env(parent = emptyenv())

  # Store callback in environment
  session$onSessionEnded <- function(callback) {
    session$._session_ended_callback <- callback
  }

  class(session) <- "ShinySession"
  return(session)
}

# ==============================================================================
# TEST: generate_ai_cache_key() - Deterministic Hash Generation
# ==============================================================================

test_that("generate_ai_cache_key produces deterministic hash", {
  metadata <- list(
    chart_type = "run",
    n_points = 24,
    signals_detected = 2,
    longest_run = 8,
    n_crossings = 3,
    centerline = 45.2,
    process_variation = "stable"
  )

  context <- list(
    data_definition = "Ventetid i minutter",
    chart_title = "Akutmodtagelse ventetid",
    y_axis_unit = "minutter",
    target_value = 30
  )

  # Same inputs should produce same key
  key1 <- generate_ai_cache_key(metadata, context)
  key2 <- generate_ai_cache_key(metadata, context)

  expect_equal(key1, key2)
  expect_type(key1, "character")
  expect_true(nchar(key1) > 0)
})

test_that("generate_ai_cache_key ignores unstable fields", {
  metadata_base <- list(
    chart_type = "run",
    n_points = 24,
    signals_detected = 2,
    longest_run = 8,
    n_crossings = 3,
    centerline = 45.2,
    process_variation = "stable"
  )

  context_base <- list(
    data_definition = "Ventetid",
    chart_title = "Akut",
    y_axis_unit = "min",
    target_value = 30
  )

  # Add unstable fields (should be ignored)
  metadata1 <- c(metadata_base, list(
    start_date = Sys.Date(),
    end_date = Sys.Date() + 30,
    plot_object = "some_plot"
  ))

  metadata2 <- c(metadata_base, list(
    start_date = Sys.Date() - 365, # Different timestamp
    end_date = Sys.Date() + 60, # Different timestamp
    plot_object = "different_plot"
  ))

  # Keys should be identical despite different unstable fields
  key1 <- generate_ai_cache_key(metadata1, context_base)
  key2 <- generate_ai_cache_key(metadata2, context_base)

  expect_equal(key1, key2)
})

test_that("generate_ai_cache_key changes with stable field changes", {
  metadata_base <- list(
    chart_type = "run",
    n_points = 24,
    signals_detected = 2,
    longest_run = 8,
    n_crossings = 3,
    centerline = 45.2,
    process_variation = "stable"
  )

  metadata_changed <- metadata_base
  metadata_changed$signals_detected <- 5 # Change stable field

  context <- list(
    data_definition = "Ventetid",
    chart_title = "Akut"
  )

  key1 <- generate_ai_cache_key(metadata_base, context)
  key2 <- generate_ai_cache_key(metadata_changed, context)

  # Keys should differ when stable fields change
  expect_false(key1 == key2)
})

test_that("generate_ai_cache_key handles NULL context fields gracefully", {
  metadata <- list(
    chart_type = "run",
    n_points = 24,
    signals_detected = 2,
    longest_run = 8,
    n_crossings = 3,
    centerline = 45.2,
    process_variation = "stable"
  )

  context_with_nulls <- list(
    data_definition = NULL,
    chart_title = NULL,
    y_axis_unit = NULL,
    target_value = NULL
  )

  # Should not error with NULL fields
  expect_no_error({
    key <- generate_ai_cache_key(metadata, context_with_nulls)
  })

  key <- generate_ai_cache_key(metadata, context_with_nulls)
  expect_type(key, "character")
  expect_true(nchar(key) > 0)
})

# ==============================================================================
# TEST: initialize_ai_cache() - Session Setup
# ==============================================================================

test_that("initialize_ai_cache creates reactiveVal in session", {
  session <- create_mock_session()

  # Cache should not exist initially
  expect_null(session$userData$ai_cache)

  # Initialize cache
  initialize_ai_cache(session)

  # Cache should now exist and be a reactiveVal
  expect_false(is.null(session$userData$ai_cache))
  expect_type(session$userData$ai_cache, "closure") # reactiveVal is a closure
})

test_that("initialize_ai_cache is idempotent", {
  session <- create_mock_session()

  # Initialize twice
  initialize_ai_cache(session)
  first_cache <- session$userData$ai_cache

  initialize_ai_cache(session)
  second_cache <- session$userData$ai_cache

  # Should be the same reactiveVal instance
  expect_identical(first_cache, second_cache)
})

test_that("initialize_ai_cache registers session cleanup callback", {
  session <- create_mock_session()

  initialize_ai_cache(session)

  # Callback should be registered
  expect_false(is.null(session$._session_ended_callback))
  expect_type(session$._session_ended_callback, "closure")
})

# ==============================================================================
# TEST: cache_ai_response() and get_cached_ai_response() - CRUD Operations
# ==============================================================================

test_that("cache_ai_response stores response correctly", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  key <- "test_key_123"
  value <- "This is a cached AI response."

  # Cache the response
  cache_ai_response(key, value, session)

  # Verify it's in the cache
  cache_contents <- shiny::isolate(session$userData$ai_cache())
  expect_true(key %in% names(cache_contents))
  expect_equal(cache_contents[[key]]$value, value)
  expect_true(inherits(cache_contents[[key]]$timestamp, "POSIXct"))
})

test_that("get_cached_ai_response retrieves stored response", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  key <- "test_key_456"
  value <- "Another cached response."

  # Store and retrieve
  cache_ai_response(key, value, session)
  retrieved <- get_cached_ai_response(key, session)

  expect_equal(retrieved, value)
})

test_that("get_cached_ai_response returns NULL for missing key", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  # Request non-existent key
  retrieved <- get_cached_ai_response("nonexistent_key", session)

  expect_null(retrieved)
})

test_that("get_cached_ai_response initializes cache if needed", {
  session <- create_mock_session()

  # Cache not initialized yet
  expect_null(session$userData$ai_cache)

  # Should auto-initialize
  retrieved <- get_cached_ai_response("some_key", session)

  expect_false(is.null(session$userData$ai_cache))
  expect_null(retrieved) # Key doesn't exist, but cache is initialized
})

# ==============================================================================
# TEST: TTL Enforcement
# ==============================================================================

test_that("get_cached_ai_response respects TTL", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  key <- "test_ttl_key"
  value <- "Response that will expire."

  # Manually create expired cache entry (timestamp in the past)
  expired_entry <- list(
    value = value,
    timestamp = Sys.time() - 7200 # 2 hours ago
  )

  shiny::isolate({
    cache <- session$userData$ai_cache()
    cache[[key]] <- expired_entry
    session$userData$ai_cache(cache)
  })

  # Mock config with 1 hour TTL
  # Note: This test assumes get_ai_config() returns cache_ttl_seconds = 3600
  # If TTL is 3600 (1 hour), entry from 2 hours ago should be expired

  retrieved <- get_cached_ai_response(key, session)

  # Should return NULL because entry is expired
  expect_null(retrieved)
})

test_that("get_cached_ai_response returns valid entry within TTL", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  key <- "test_valid_ttl_key"
  value <- "Fresh response."

  # Create recent cache entry (should be within TTL)
  cache_ai_response(key, value, session)

  # Retrieve immediately (should be valid)
  retrieved <- get_cached_ai_response(key, session)

  expect_equal(retrieved, value)
})

# ==============================================================================
# TEST: clear_ai_cache() - Manual Cache Clearing
# ==============================================================================

test_that("clear_ai_cache removes all entries", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  # Add multiple entries
  cache_ai_response("key1", "value1", session)
  cache_ai_response("key2", "value2", session)
  cache_ai_response("key3", "value3", session)

  # Verify entries exist
  cache_before <- shiny::isolate(session$userData$ai_cache())
  expect_equal(length(cache_before), 3)

  # Clear cache
  clear_ai_cache(session)

  # Verify cache is empty
  cache_after <- shiny::isolate(session$userData$ai_cache())
  expect_equal(length(cache_after), 0)
})

test_that("clear_ai_cache handles already empty cache", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  # Clear empty cache (should not error)
  expect_no_error({
    clear_ai_cache(session)
  })

  cache <- shiny::isolate(session$userData$ai_cache())
  expect_equal(length(cache), 0)
})

test_that("clear_ai_cache handles uninitialized cache gracefully", {
  session <- create_mock_session()

  # Cache not initialized, but clear should be safe
  expect_no_error({
    clear_ai_cache(session)
  })
})

# ==============================================================================
# TEST: get_ai_cache_stats() - Cache Statistics
# ==============================================================================

test_that("get_ai_cache_stats returns correct entry count", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  # Add entries
  cache_ai_response("key1", "value1", session)
  cache_ai_response("key2", "value2", session)

  stats <- get_ai_cache_stats(session)

  expect_equal(stats$entries, 2)
})

test_that("get_ai_cache_stats calculates total size correctly", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  value1 <- "Short" # 5 chars
  value2 <- "Longer response text" # 20 chars

  cache_ai_response("key1", value1, session)
  cache_ai_response("key2", value2, session)

  stats <- get_ai_cache_stats(session)

  expect_equal(stats$total_size, nchar(value1) + nchar(value2))
})

test_that("get_ai_cache_stats returns NA for oldest_entry when empty", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  stats <- get_ai_cache_stats(session)

  expect_equal(stats$entries, 0)
  expect_equal(stats$total_size, 0)
  expect_true(is.na(stats$oldest_entry))
})

test_that("get_ai_cache_stats returns oldest timestamp correctly", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  # Manually create entries with different timestamps
  shiny::isolate({
    cache <- session$userData$ai_cache()

    old_time <- Sys.time() - 3600 # 1 hour ago
    new_time <- Sys.time()

    cache[["old_key"]] <- list(value = "old", timestamp = old_time)
    cache[["new_key"]] <- list(value = "new", timestamp = new_time)

    session$userData$ai_cache(cache)
  })

  stats <- get_ai_cache_stats(session)

  expect_equal(stats$entries, 2)
  # Store old_time for comparison
  old_time <- Sys.time() - 3600
  expect_equal(stats$oldest_entry, as.numeric(old_time), tolerance = 1)
})

test_that("get_ai_cache_stats handles uninitialized cache", {
  session <- create_mock_session()

  stats <- get_ai_cache_stats(session)

  expect_equal(stats$entries, 0)
  expect_equal(stats$total_size, 0)
  expect_true(is.na(stats$oldest_entry))
})

# ==============================================================================
# TEST: Session Cleanup on End
# ==============================================================================

test_that("session end callback clears cache", {
  session <- create_mock_session()
  initialize_ai_cache(session)

  # Add entries
  cache_ai_response("key1", "value1", session)
  cache_ai_response("key2", "value2", session)

  cache_before <- shiny::isolate(session$userData$ai_cache())
  expect_equal(length(cache_before), 2)

  # Simulate session end
  session$._session_ended_callback()

  # Cache should be cleared
  cache_after <- shiny::isolate(session$userData$ai_cache())
  expect_equal(length(cache_after), 0)
})

# ==============================================================================
# TEST: Integration - Full Cache Workflow
# ==============================================================================

test_that("full cache workflow: store, retrieve, expire, clear", {
  session <- create_mock_session()

  # 1. Initialize
  initialize_ai_cache(session)

  # 2. Store response
  metadata <- list(
    chart_type = "i",
    n_points = 30,
    signals_detected = 1,
    longest_run = 5,
    n_crossings = 8,
    centerline = 12.5,
    process_variation = "controlled"
  )

  context <- list(
    data_definition = "Infektionsrate per 1000 patienter",
    chart_title = "Infektioner i kirurgisk afdeling",
    y_axis_unit = "per 1000",
    target_value = 10
  )

  key <- generate_ai_cache_key(metadata, context)
  response_text <- "Denne proces viser god kontrol med stabil variation..."

  cache_ai_response(key, response_text, session)

  # 3. Retrieve (should hit cache)
  retrieved <- get_cached_ai_response(key, session)
  expect_equal(retrieved, response_text)

  # 4. Check stats
  stats <- get_ai_cache_stats(session)
  expect_equal(stats$entries, 1)
  expect_equal(stats$total_size, nchar(response_text))

  # 5. Clear cache
  clear_ai_cache(session)

  # 6. Verify cleared
  stats_after <- get_ai_cache_stats(session)
  expect_equal(stats_after$entries, 0)

  # 7. Try to retrieve (should miss)
  retrieved_after_clear <- get_cached_ai_response(key, session)
  expect_null(retrieved_after_clear)
})

test_that("cache key collision is extremely unlikely", {
  # Generate many different metadata/context combinations
  # and verify they produce unique keys

  keys <- character(100)

  for (i in 1:100) {
    metadata <- list(
      chart_type = sample(c("run", "i", "p", "c", "u"), 1),
      n_points = sample(10:100, 1),
      signals_detected = sample(0:10, 1),
      longest_run = sample(1:20, 1),
      n_crossings = sample(0:50, 1),
      centerline = runif(1, 0, 100),
      process_variation = sample(c("stable", "unstable", "controlled"), 1)
    )

    context <- list(
      data_definition = paste0("Definition ", i),
      chart_title = paste0("Title ", i),
      y_axis_unit = sample(c("%", "antal", "dage"), 1),
      target_value = sample(1:100, 1)
    )

    keys[i] <- generate_ai_cache_key(metadata, context)
  }

  # All keys should be unique
  expect_equal(length(unique(keys)), 100)
})
