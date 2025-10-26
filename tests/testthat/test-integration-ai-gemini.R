# test-integration-ai-gemini.R
# Integration tests for AI feature with real Gemini API
#
# Disse tests kører kun hvis GOOGLE_API_KEY er sat i environment.
# De tester den fulde AI workflow end-to-end med rigtig API.
#
# Run manually: testthat::test_file("tests/testthat/test-integration-ai-gemini.R")
# Skip hvis API key mangler: testthat::skip_if_not(validate_gemini_setup())

# Setup -----------------------------------------------------------------------

test_that("Gemini API integration setup", {
  skip_if_not(
    validate_gemini_setup(),
    "Gemini API key not configured - set GOOGLE_API_KEY environment variable"
  )

  # If we reach here, API key is configured
  expect_true(validate_gemini_setup())
})

# End-to-End Workflow ---------------------------------------------------------

test_that("Full AI suggestion generation workflow with real API", {
  skip_if_not(
    validate_gemini_setup(),
    "Gemini API key not configured"
  )

  # Load test fixture
  spc_result <- readRDS("fixtures/sample_spc_result.rds")
  expect_type(spc_result, "list")
  expect_true(!is.null(spc_result$metadata))
  expect_true(!is.null(spc_result$qic_data))

  # Prepare context (realistic scenario)
  context <- list(
    data_definition = "Antal infektioner per 1000 patienter på intensiv afdeling",
    chart_title = "Infektionsrate intensiv 2024",
    y_axis_unit = "antal per 1000",
    target_value = 10
  )

  # Create mock session for cache
  session <- shiny::MockShinySession$new()

  # Generate suggestion (real API call)
  suggestion <- generate_improvement_suggestion(
    spc_result = spc_result,
    context = context,
    session = session,
    max_chars = 350
  )

  # Verify result
  expect_type(suggestion, "character")
  expect_true(!is.null(suggestion))
  expect_gt(nchar(suggestion), 50)  # Should be meaningful text
  expect_lte(nchar(suggestion), 350)  # Should respect max_chars

  # Verify suggestion contains expected elements
  # (Danish text about process variation or target comparison)
  expect_true(
    grepl("variation|varierer|målet|forbedring|naturlig", suggestion, ignore.case = TRUE),
    info = "Suggestion should contain relevant Danish SPC terminology"
  )

  # Log for manual verification
  message("\n=== Generated AI Suggestion ===")
  message(suggestion)
  message("===============================\n")
})

test_that("Cache persistence across multiple calls", {
  skip_if_not(validate_gemini_setup(), "Gemini API key not configured")

  spc_result <- readRDS("fixtures/sample_spc_result.rds")
  context <- list(
    data_definition = "Test indikator",
    chart_title = "Test chart",
    y_axis_unit = "antal",
    target_value = 35
  )

  session <- shiny::MockShinySession$new()

  # First call - should hit API
  start_time_1 <- Sys.time()
  suggestion_1 <- generate_improvement_suggestion(
    spc_result, context, session, max_chars = 350
  )
  duration_1 <- as.numeric(difftime(Sys.time(), start_time_1, units = "secs"))

  expect_true(!is.null(suggestion_1))

  # Second call - should hit cache (instant)
  start_time_2 <- Sys.time()
  suggestion_2 <- generate_improvement_suggestion(
    spc_result, context, session, max_chars = 350
  )
  duration_2 <- as.numeric(difftime(Sys.time(), start_time_2, units = "secs"))

  expect_equal(suggestion_1, suggestion_2, info = "Cache should return identical result")
  expect_lt(duration_2, duration_1 / 10, info = "Cache hit should be 10x faster than API call")

  message(sprintf(
    "Performance: API call %.2fs, Cache hit %.3fs (%.0fx faster)",
    duration_1, duration_2, duration_1 / duration_2
  ))
})

# Different Chart Types -------------------------------------------------------

test_that("AI suggestions work for different chart types", {
  skip_if_not(validate_gemini_setup(), "Gemini API key not configured")

  # Test multiple chart types
  chart_types <- c("run", "p", "c", "i")

  session <- shiny::MockShinySession$new()

  for (chart_type in chart_types) {
    # Modify fixture to test chart type
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    spc_result$metadata$chart_type <- chart_type

    context <- list(
      data_definition = sprintf("Test indikator (%s chart)", chart_type),
      chart_title = sprintf("%s Chart Test", toupper(chart_type)),
      y_axis_unit = "antal",
      target_value = 35
    )

    suggestion <- generate_improvement_suggestion(
      spc_result, context, session, max_chars = 350
    )

    expect_true(
      !is.null(suggestion),
      info = sprintf("Suggestion should be generated for chart_type=%s", chart_type)
    )

    expect_gt(
      nchar(suggestion), 30,
      info = sprintf("Suggestion for chart_type=%s should be meaningful", chart_type)
    )

    message(sprintf("✓ Chart type '%s' suggestion generated (%d chars)", chart_type, nchar(suggestion)))
  }
})

# Edge Cases ------------------------------------------------------------------

test_that("AI handles missing context gracefully", {
  skip_if_not(validate_gemini_setup(), "Gemini API key not configured")

  spc_result <- readRDS("fixtures/sample_spc_result.rds")

  # Minimal context (only required fields empty)
  minimal_context <- list(
    data_definition = "",  # Empty but present
    chart_title = "",
    y_axis_unit = "count",
    target_value = NULL  # Missing target
  )

  session <- shiny::MockShinySession$new()

  suggestion <- generate_improvement_suggestion(
    spc_result, minimal_context, session, max_chars = 350
  )

  # Should still generate something meaningful
  expect_true(!is.null(suggestion))
  expect_gt(nchar(suggestion), 30)
  message("✓ AI handled missing context gracefully")
})

test_that("AI respects max_chars constraint", {
  skip_if_not(validate_gemini_setup(), "Gemini API key not configured")

  spc_result <- readRDS("fixtures/sample_spc_result.rds")
  context <- list(
    data_definition = "Very detailed description of the indicator with lots of context and background information",
    chart_title = "Detailed Title",
    y_axis_unit = "antal",
    target_value = 35
  )

  session <- shiny::MockShinySession$new()

  # Test with stricter max_chars
  max_chars_values <- c(150, 250, 350)

  for (max_val in max_chars_values) {
    suggestion <- generate_improvement_suggestion(
      spc_result, context, session, max_chars = max_val
    )

    expect_lte(
      nchar(suggestion), max_val,
      info = sprintf("Suggestion should not exceed max_chars=%d", max_val)
    )

    message(sprintf("✓ max_chars=%d constraint respected (%d chars generated)", max_val, nchar(suggestion)))
  }
})

# Performance Test ------------------------------------------------------------

test_that("Performance test: 20 requests in 2 minutes", {
  skip_if_not(validate_gemini_setup(), "Gemini API key not configured")
  skip_if_not(interactive(), "Performance test only runs interactively")

  spc_result <- readRDS("fixtures/sample_spc_result.rds")
  session <- shiny::MockShinySession$new()

  n_requests <- 20
  timeout_seconds <- 120
  results <- list()

  message(sprintf("\nStarting performance test: %d requests in %d seconds", n_requests, timeout_seconds))

  start_time <- Sys.time()

  for (i in seq_len(n_requests)) {
    # Vary context slightly to test cache behavior
    context <- list(
      data_definition = sprintf("Test indikator variation %d", i %% 5),  # 5 unique contexts
      chart_title = sprintf("Chart %d", i),
      y_axis_unit = "antal",
      target_value = 35 + (i %% 3) * 5  # 3 unique targets
    )

    req_start <- Sys.time()
    suggestion <- generate_improvement_suggestion(
      spc_result, context, session, max_chars = 350
    )
    req_duration <- as.numeric(difftime(Sys.time(), req_start, units = "secs"))

    results[[i]] <- list(
      success = !is.null(suggestion),
      duration = req_duration,
      length = if (!is.null(suggestion)) nchar(suggestion) else 0
    )

    if (i %% 5 == 0) {
      message(sprintf("  Completed %d/%d requests...", i, n_requests))
    }
  }

  total_duration <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # Analyze results
  success_count <- sum(sapply(results, function(x) x$success))
  durations <- sapply(results, function(x) x$duration)
  mean_duration <- mean(durations)
  cache_hits <- sum(durations < 0.1)  # Requests under 100ms are likely cache hits

  # Expectations
  expect_equal(success_count, n_requests, info = "All requests should succeed")
  expect_lt(total_duration, timeout_seconds, info = "Should complete within timeout")
  expect_gt(cache_hits, 0, info = "Should have some cache hits")

  cache_hit_rate <- cache_hits / n_requests * 100

  message(sprintf("\n=== Performance Test Results ==="))
  message(sprintf("Total requests: %d", n_requests))
  message(sprintf("Successful: %d (%.1f%%)", success_count, success_count / n_requests * 100))
  message(sprintf("Total duration: %.1f seconds", total_duration))
  message(sprintf("Mean duration per request: %.2f seconds", mean_duration))
  message(sprintf("Cache hits: %d (%.1f%%)", cache_hits, cache_hit_rate))
  message(sprintf("Throughput: %.1f requests/minute", n_requests / total_duration * 60))
  message(sprintf("================================\n"))

  expect_gt(
    cache_hit_rate, 50,
    info = "Cache hit rate should be > 50% with repeated contexts"
  )
})
