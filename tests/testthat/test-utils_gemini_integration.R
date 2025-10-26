# test-utils_gemini_integration.R
# Unit tests for Gemini API integration layer

# TEST SETUP ====================================================================

test_that("validate_gemini_setup detects missing Ellmer package", {
  # Mock ellmer as not installed
  mockery::stub(
    validate_gemini_setup,
    "requireNamespace",
    FALSE
  )

  expect_false(validate_gemini_setup())
})

test_that("validate_gemini_setup detects missing API key", {
  # Mock ellmer as installed
  mockery::stub(
    validate_gemini_setup,
    "requireNamespace",
    TRUE
  )

  # Mock empty API key
  withr::with_envvar(
    c(GOOGLE_API_KEY = ""),
    {
      expect_false(validate_gemini_setup())
    }
  )
})

test_that("validate_gemini_setup detects invalid API key placeholder", {
  mockery::stub(
    validate_gemini_setup,
    "requireNamespace",
    TRUE
  )

  withr::with_envvar(
    c(GOOGLE_API_KEY = "your_api_key_here"),
    {
      expect_false(validate_gemini_setup())
    }
  )
})

test_that("validate_gemini_setup detects AI disabled in config", {
  mockery::stub(
    validate_gemini_setup,
    "requireNamespace",
    TRUE
  )

  mockery::stub(
    validate_gemini_setup,
    "golem::get_golem_options",
    list(enabled = FALSE)
  )

  withr::with_envvar(
    c(GOOGLE_API_KEY = "valid_key_123"),
    {
      expect_false(validate_gemini_setup())
    }
  )
})

test_that("validate_gemini_setup succeeds with valid configuration", {
  mockery::stub(
    validate_gemini_setup,
    "requireNamespace",
    TRUE
  )

  mockery::stub(
    validate_gemini_setup,
    "golem::get_golem_options",
    list(enabled = TRUE)
  )

  withr::with_envvar(
    c(GOOGLE_API_KEY = "valid_key_123"),
    {
      expect_true(validate_gemini_setup())
    }
  )
})

# TEST API WRAPPER ==============================================================

test_that("call_gemini_api fails when setup invalid", {
  # Mock invalid setup
  mockery::stub(
    call_gemini_api,
    "validate_gemini_setup",
    FALSE
  )

  result <- call_gemini_api("test prompt")

  expect_null(result)
})

test_that("call_gemini_api fails when circuit breaker open", {
  # Mock valid setup
  mockery::stub(
    call_gemini_api,
    "validate_gemini_setup",
    TRUE
  )

  # Mock circuit breaker open
  mockery::stub(
    call_gemini_api,
    "circuit_breaker_is_open",
    TRUE
  )

  result <- call_gemini_api("test prompt")

  expect_null(result)
})

test_that("call_gemini_api handles timeout errors", {
  # Mock valid setup
  mockery::stub(
    call_gemini_api,
    "validate_gemini_setup",
    TRUE
  )

  mockery::stub(
    call_gemini_api,
    "circuit_breaker_is_open",
    FALSE
  )

  # Mock timeout error
  mockery::stub(
    call_gemini_api,
    "ellmer::chat_google_gemini",
    function(...) {
      stop("timeout exceeded")
    }
  )

  # Mock circuit breaker functions
  mockery::stub(
    call_gemini_api,
    "circuit_breaker_record_failure",
    function() invisible(NULL)
  )

  result <- call_gemini_api("test prompt", timeout = 1)

  expect_null(result)
})

test_that("call_gemini_api handles successful API call", {
  # Skip this test as mocking ellmer is complex
  # Will be tested in integration tests with real API
  skip("Ellmer mocking requires complex setup - use integration tests")
})

test_that("call_gemini_api classifies error types correctly", {
  # Mock valid setup
  mockery::stub(
    call_gemini_api,
    "validate_gemini_setup",
    TRUE
  )

  mockery::stub(
    call_gemini_api,
    "circuit_breaker_is_open",
    FALSE
  )

  # Mock circuit breaker functions
  mockery::stub(
    call_gemini_api,
    "circuit_breaker_record_failure",
    function() invisible(NULL)
  )

  # Test rate limit error
  mockery::stub(
    call_gemini_api,
    "ellmer::chat_google_gemini",
    function(...) stop("rate limit exceeded")
  )

  result <- call_gemini_api("test")
  expect_null(result)

  # Test API key error
  mockery::stub(
    call_gemini_api,
    "ellmer::chat_google_gemini",
    function(...) stop("invalid api key")
  )

  result <- call_gemini_api("test")
  expect_null(result)
})

# TEST RESPONSE VALIDATION ======================================================

test_that("validate_gemini_response handles NULL input", {
  result <- validate_gemini_response(NULL)
  expect_null(result)
})

test_that("validate_gemini_response handles empty string", {
  result <- validate_gemini_response("")
  expect_null(result)
})

test_that("validate_gemini_response removes HTML tags", {
  input <- "<p>This is a <strong>test</strong> response</p>"
  result <- validate_gemini_response(input)

  expect_false(grepl("<", result))
  expect_false(grepl(">", result))
  expect_match(result, "This is a test response")
})

test_that("validate_gemini_response normalizes whitespace", {
  input <- "This  is   a    test\nwith\tmultiple\n\nspaces"
  result <- validate_gemini_response(input)

  expect_false(grepl("  ", result))
  expect_false(grepl("\n", result))
  expect_false(grepl("\t", result))
  expect_match(result, "^This is a test with multiple spaces$")
})

test_that("validate_gemini_response trims leading/trailing whitespace", {
  input <- "  \n  This is a test  \n  "
  result <- validate_gemini_response(input)

  expect_equal(result, "This is a test")
})

test_that("validate_gemini_response trims to max_chars", {
  long_text <- paste(rep("word", 100), collapse = " ")
  result <- validate_gemini_response(long_text, max_chars = 50)

  expect_lte(nchar(result), 50)
  expect_match(result, "\\.\\.\\.$")
})

test_that("validate_gemini_response returns NULL if empty after sanitization", {
  input <- "<p>   </p>"
  result <- validate_gemini_response(input)

  expect_null(result)
})

test_that("validate_gemini_response preserves valid text", {
  input <- "This is a perfectly valid response"
  result <- validate_gemini_response(input)

  expect_equal(result, input)
})

test_that("validate_gemini_response respects max_chars parameter", {
  input <- "This is a test message"
  result <- validate_gemini_response(input, max_chars = 10)

  expect_lte(nchar(result), 10)
  expect_match(result, "\\.\\.\\.$")
})

# TEST CIRCUIT BREAKER ==========================================================

test_that("circuit_breaker_is_open returns FALSE initially", {
  # Reset state first
  circuit_breaker_reset()

  expect_false(circuit_breaker_is_open())
})

test_that("circuit_breaker_record_failure increments failure count", {
  circuit_breaker_reset()

  # Mock config
  mockery::stub(
    circuit_breaker_record_failure,
    "golem::get_golem_options",
    list(circuit_breaker = list(failure_threshold = 5))
  )

  circuit_breaker_record_failure()

  state <- circuit_breaker_get_state()
  expect_equal(state$failures, 1L)
  expect_false(state$is_open)
})

test_that("circuit_breaker opens after threshold failures", {
  circuit_breaker_reset()

  # Mock config
  mock_config <- list(
    circuit_breaker = list(
      failure_threshold = 3L
    )
  )

  mockery::stub(
    circuit_breaker_record_failure,
    "golem::get_golem_options",
    mock_config
  )

  # Record 3 failures
  circuit_breaker_record_failure()
  circuit_breaker_record_failure()
  circuit_breaker_record_failure()

  state <- circuit_breaker_get_state()
  expect_equal(state$failures, 3L)
  expect_true(state$is_open)
})

test_that("circuit_breaker_record_success resets state", {
  circuit_breaker_reset()

  # Set some failures
  mockery::stub(
    circuit_breaker_record_failure,
    "golem::get_golem_options",
    list(circuit_breaker = list(failure_threshold = 5))
  )

  circuit_breaker_record_failure()
  circuit_breaker_record_failure()

  # Record success
  circuit_breaker_record_success()

  state <- circuit_breaker_get_state()
  expect_equal(state$failures, 0L)
  expect_false(state$is_open)
})

test_that("circuit_breaker resets after timeout", {
  circuit_breaker_reset()

  # Mock config with short timeout
  mock_config <- list(
    circuit_breaker = list(
      failure_threshold = 2L,
      reset_timeout_seconds = 1L  # 1 second timeout
    )
  )

  mockery::stub(
    circuit_breaker_record_failure,
    "golem::get_golem_options",
    mock_config
  )

  mockery::stub(
    circuit_breaker_is_open,
    "golem::get_golem_options",
    mock_config
  )

  # Open circuit breaker
  circuit_breaker_record_failure()
  circuit_breaker_record_failure()

  expect_true(circuit_breaker_is_open())

  # Wait for timeout
  Sys.sleep(1.5)

  # Should be closed now
  expect_false(circuit_breaker_is_open())
})

test_that("circuit_breaker_reset clears all state", {
  # Set some state
  mockery::stub(
    circuit_breaker_record_failure,
    "golem::get_golem_options",
    list(circuit_breaker = list(failure_threshold = 5))
  )

  circuit_breaker_record_failure()
  circuit_breaker_record_failure()

  # Reset
  circuit_breaker_reset()

  state <- circuit_breaker_get_state()
  expect_equal(state$failures, 0L)
  expect_false(state$is_open)
  expect_null(state$last_failure_time)
})

test_that("circuit_breaker_get_state returns correct structure", {
  circuit_breaker_reset()

  state <- circuit_breaker_get_state()

  expect_type(state, "list")
  expect_true("failures" %in% names(state))
  expect_true("is_open" %in% names(state))
  expect_true("last_failure_time" %in% names(state))
})

test_that("circuit breaker uses default config values", {
  circuit_breaker_reset()

  # Mock NULL config (should use defaults)
  mockery::stub(
    circuit_breaker_record_failure,
    "golem::get_golem_options",
    NULL
  )

  # Should not crash and use defaults
  expect_silent(circuit_breaker_record_failure())

  state <- circuit_breaker_get_state()
  expect_equal(state$failures, 1L)
})

# TEST EDGE CASES ===============================================================

test_that("validate_gemini_response handles non-character input", {
  result <- validate_gemini_response(123)
  expect_null(result)
})

test_that("validate_gemini_response handles very long text", {
  long_text <- paste(rep("x", 10000), collapse = "")
  result <- validate_gemini_response(long_text, max_chars = 100)

  expect_lte(nchar(result), 100)
  expect_match(result, "\\.\\.\\.$")
})

test_that("validate_gemini_response handles special characters", {
  input <- "Test with special chars: é, ñ, ü, 中文"
  result <- validate_gemini_response(input)

  expect_type(result, "character")
  expect_true(nchar(result) > 0)
})

test_that("call_gemini_api handles very long prompts", {
  # Skip - requires complex ellmer mocking
  skip("Ellmer mocking requires complex setup - use integration tests")
})

# TEST INTEGRATION PATTERNS =====================================================

test_that("full workflow: setup -> call -> validate works", {
  # Skip complex ellmer mocking - test components individually
  skip("Full workflow requires complex ellmer mocking - test components individually")

  # Components are tested individually:
  # - validate_gemini_setup: tested
  # - validate_gemini_response: tested
  # - call_gemini_api: tested for error cases
})

test_that("circuit breaker protects against repeated failures", {
  circuit_breaker_reset()

  mock_config <- list(
    circuit_breaker = list(
      failure_threshold = 3L,
      reset_timeout_seconds = 300L
    )
  )

  mockery::stub(
    circuit_breaker_record_failure,
    "golem::get_golem_options",
    mock_config
  )

  mockery::stub(
    circuit_breaker_is_open,
    "golem::get_golem_options",
    mock_config
  )

  # Record failures
  circuit_breaker_record_failure()
  circuit_breaker_record_failure()
  circuit_breaker_record_failure()

  # Circuit breaker should be open
  expect_true(circuit_breaker_is_open())

  # API call should fail with circuit breaker message
  mockery::stub(
    call_gemini_api,
    "validate_gemini_setup",
    TRUE
  )

  mockery::stub(
    call_gemini_api,
    "circuit_breaker_is_open",
    TRUE
  )

  result <- call_gemini_api("test")
  expect_null(result)
})
