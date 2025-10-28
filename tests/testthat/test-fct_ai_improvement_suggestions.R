# test-fct_ai_improvement_suggestions.R
# Comprehensive unit tests for AI improvement suggestion core logic
#
# Test Coverage:
# 1. extract_spc_metadata() - SPC metadata extraction from BFHcharts output
# 2. determine_target_comparison() - Target comparison logic
# 3. build_gemini_prompt() - Prompt building with templates
# 4. generate_improvement_suggestion() - Main facade with mocked dependencies

library(testthat)
library(mockery)

# ============================================================================
# Test Suite 1: extract_spc_metadata()
# ============================================================================

describe("extract_spc_metadata()", {

  it("returns complete structure from valid spc_result", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    metadata <- extract_spc_metadata(spc_result)

    expect_type(metadata, "list")
    expect_named(metadata, c(
      "chart_type", "chart_type_dansk", "n_points", "signals_detected",
      "longest_run", "n_crossings", "n_crossings_min",
      "centerline", "start_date", "end_date", "process_variation"
    ))

    # Verify values match fixture
    expect_equal(metadata$chart_type, "run")
    expect_equal(metadata$n_points, 24)
    expect_equal(metadata$signals_detected, 3)
    expect_equal(metadata$longest_run, 8)
    expect_equal(metadata$n_crossings, 5)
    expect_equal(metadata$n_crossings_min, 7)
    expect_equal(metadata$centerline, 36)
    expect_equal(metadata$start_date, "2024-01-01")
    expect_equal(metadata$end_date, "2025-12-01")
    expect_equal(metadata$process_variation, "ikke naturligt")
  })

  it("sets process_variation to 'ikke naturligt' when signals > 0", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    spc_result$metadata$signals_detected <- 2

    metadata <- extract_spc_metadata(spc_result)

    expect_equal(metadata$process_variation, "ikke naturligt")
  })

  it("sets process_variation to 'naturligt' when signals = 0", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    spc_result$metadata$signals_detected <- 0

    metadata <- extract_spc_metadata(spc_result)

    expect_equal(metadata$process_variation, "naturligt")
  })

  it("calculates centerline from qic_data$cl", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")

    metadata <- extract_spc_metadata(spc_result)

    # Verify centerline is mean of cl column
    expected_cl <- round(mean(spc_result$qic_data$cl, na.rm = TRUE), 2)
    expect_equal(metadata$centerline, expected_cl)
  })

  it("extracts start_date and end_date from qic_data$x", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")

    metadata <- extract_spc_metadata(spc_result)

    expect_equal(metadata$start_date, as.character(spc_result$qic_data$x[1]))
    expect_equal(metadata$end_date, as.character(spc_result$qic_data$x[nrow(spc_result$qic_data)]))
  })

  it("maps chart_type to Danish via map_chart_type_to_danish()", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")

    # Mock map_chart_type_to_danish
    stub(extract_spc_metadata, "map_chart_type_to_danish",
         function(chart_type) "serieplot (run chart)")

    metadata <- extract_spc_metadata(spc_result)

    expect_equal(metadata$chart_type_dansk, "serieplot (run chart)")
  })

  it("returns NULL for NULL input", {
    result <- extract_spc_metadata(NULL)

    expect_null(result)
  })

  it("returns NULL for non-list input", {
    result <- extract_spc_metadata("not a list")

    expect_null(result)
  })

  it("returns NULL when metadata component is missing", {
    spc_result <- list(qic_data = data.frame(x = 1:10, y = 1:10))

    result <- extract_spc_metadata(spc_result)

    expect_null(result)
  })

  it("handles missing qic_data component gracefully", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    spc_result$qic_data <- NULL

    metadata <- extract_spc_metadata(spc_result)

    # Should still extract metadata fields
    expect_equal(metadata$chart_type, "run")
    expect_equal(metadata$n_points, 24)

    # But qic_data fields should have defaults
    expect_true(is.na(metadata$centerline))
    expect_equal(metadata$start_date, "Ikke angivet")
    expect_equal(metadata$end_date, "Ikke angivet")
  })

  it("handles empty qic_data component", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    spc_result$qic_data <- data.frame()

    metadata <- extract_spc_metadata(spc_result)

    expect_true(is.na(metadata$centerline))
    expect_equal(metadata$start_date, "Ikke angivet")
    expect_equal(metadata$end_date, "Ikke angivet")
  })

  it("handles missing anhoej_rules gracefully", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    spc_result$metadata$anhoej_rules <- NULL

    metadata <- extract_spc_metadata(spc_result)

    # Should use fallback values
    expect_equal(metadata$longest_run, 0)
    expect_equal(metadata$n_crossings, 0)
    expect_equal(metadata$n_crossings_min, 0)
  })

  it("handles missing cl column in qic_data", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    spc_result$qic_data$cl <- NULL

    metadata <- extract_spc_metadata(spc_result)

    expect_true(is.na(metadata$centerline))
  })

  it("handles all NA values in cl column", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    spc_result$qic_data$cl <- rep(NA_real_, nrow(spc_result$qic_data))

    metadata <- extract_spc_metadata(spc_result)

    expect_true(is.na(metadata$centerline))
  })

  it("handles missing x column in qic_data", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    spc_result$qic_data$x <- NULL

    metadata <- extract_spc_metadata(spc_result)

    expect_equal(metadata$start_date, "Ikke angivet")
    expect_equal(metadata$end_date, "Ikke angivet")
  })
})

# ============================================================================
# Test Suite 2: determine_target_comparison()
# ============================================================================

describe("determine_target_comparison()", {

  it("returns 'over målet' when centerline > target (outside 5% tolerance)", {
    result <- determine_target_comparison(12.5, 10)

    expect_equal(result, "over målet")
  })

  it("returns 'under målet' when centerline < target (outside 5% tolerance)", {
    result <- determine_target_comparison(8.5, 10)

    expect_equal(result, "under målet")
  })

  it("returns 'ved målet' when within 5% tolerance (above)", {
    # 10.3 is within 5% of 10 (tolerance = 0.5)
    result <- determine_target_comparison(10.3, 10)

    expect_equal(result, "ved målet")
  })

  it("returns 'ved målet' when within 5% tolerance (below)", {
    # 9.7 is within 5% of 10 (tolerance = 0.5)
    result <- determine_target_comparison(9.7, 10)

    expect_equal(result, "ved målet")
  })

  it("returns 'ved målet' when exactly at target", {
    result <- determine_target_comparison(10, 10)

    expect_equal(result, "ved målet")
  })

  it("returns 'ikke angivet' for NULL target", {
    result <- determine_target_comparison(12.5, NULL)

    expect_equal(result, "ikke angivet")
  })

  it("returns 'ikke angivet' for NA target", {
    result <- determine_target_comparison(12.5, NA)

    expect_equal(result, "ikke angivet")
  })

  it("returns 'ikke angivet' for empty string target", {
    result <- determine_target_comparison(12.5, "")

    expect_equal(result, "ikke angivet")
  })

  it("returns 'ikke angivet' for NULL centerline", {
    result <- determine_target_comparison(NULL, 10)

    expect_equal(result, "ikke angivet")
  })

  it("returns 'ikke angivet' for NA centerline", {
    result <- determine_target_comparison(NA, 10)

    expect_equal(result, "ikke angivet")
  })

  it("returns 'ikke angivet' for zero-length target", {
    result <- determine_target_comparison(12.5, numeric(0))

    expect_equal(result, "ikke angivet")
  })

  it("handles numeric strings for target", {
    result <- determine_target_comparison(12.5, "10")

    expect_equal(result, "over målet")
  })

  it("handles negative values correctly", {
    result <- determine_target_comparison(-12.5, -10)

    expect_equal(result, "under målet")
  })

  it("calculates tolerance correctly for different target values", {
    # Target = 100, tolerance = 5
    # 104 is within tolerance
    result1 <- determine_target_comparison(104, 100)
    expect_equal(result1, "ved målet")

    # 106 is outside tolerance
    result2 <- determine_target_comparison(106, 100)
    expect_equal(result2, "over målet")
  })
})

# ============================================================================
# Test Suite 3: build_gemini_prompt()
# ============================================================================

describe("build_gemini_prompt()", {

  it("returns character string prompt", {
    metadata <- list(
      chart_type = "run",
      chart_type_dansk = "serieplot (run chart)",
      n_points = 24,
      signals_detected = 3,
      longest_run = 8,
      n_crossings = 5,
      n_crossings_min = 7,
      centerline = 36,
      start_date = "2024-01-01",
      end_date = "2024-12-01",
      process_variation = "ikke naturligt"
    )

    context <- list(
      data_definition = "Ventetid til operation",
      chart_title = "Ventetid 2024",
      y_axis_unit = "dage",
      target_value = 30
    )

    # Mock dependencies
    stub(build_gemini_prompt, "get_improvement_suggestion_template",
         function() "Template with {chart_type_dansk} and {target_comparison}")
    stub(build_gemini_prompt, "interpolate_prompt",
         function(template, data) "Mocked prompt text")

    result <- build_gemini_prompt(metadata, context)

    expect_type(result, "character")
    expect_equal(result, "Mocked prompt text")
  })

  it("calls get_improvement_suggestion_template()", {
    metadata <- list(chart_type = "run", centerline = 36)
    context <- list(data_definition = "Test", target_value = 30)

    mock_template <- mock("Mock template")
    stub(build_gemini_prompt, "get_improvement_suggestion_template", mock_template)
    stub(build_gemini_prompt, "interpolate_prompt", function(t, d) "result")

    build_gemini_prompt(metadata, context)

    expect_called(mock_template, 1)
  })

  it("calls determine_target_comparison() with correct args", {
    metadata <- list(chart_type = "run", centerline = 36)
    context <- list(data_definition = "Test", target_value = 30)

    stub(build_gemini_prompt, "get_improvement_suggestion_template", function() "template")

    # Spy on determine_target_comparison (it's called internally)
    mock_comparison <- mock("over målet")
    stub(build_gemini_prompt, "determine_target_comparison", mock_comparison)
    stub(build_gemini_prompt, "interpolate_prompt", function(t, d) "result")

    build_gemini_prompt(metadata, context)

    expect_called(mock_comparison, 1)
    expect_args(mock_comparison, 1, 36, 30)
  })

  it("calls interpolate_prompt() with combined data", {
    metadata <- list(chart_type = "run", centerline = 36)
    context <- list(data_definition = "Test", target_value = 30)

    stub(build_gemini_prompt, "get_improvement_suggestion_template", function() "template")
    stub(build_gemini_prompt, "determine_target_comparison", function(c, t) "over målet")

    mock_interpolate <- mock("interpolated result")
    stub(build_gemini_prompt, "interpolate_prompt", mock_interpolate)

    build_gemini_prompt(metadata, context)

    expect_called(mock_interpolate, 1)

    # Check that args include both metadata and context
    call_args <- mock_args(mock_interpolate)[[1]]
    expect_equal(call_args[[1]], "template")
    expect_type(call_args[[2]], "list")
    expect_true("chart_type" %in% names(call_args[[2]]))
    expect_true("data_definition" %in% names(call_args[[2]]))
    expect_true("target_comparison" %in% names(call_args[[2]]))
  })

  it("returns NULL if metadata is NULL", {
    context <- list(data_definition = "Test", target_value = 30)

    result <- build_gemini_prompt(NULL, context)

    expect_null(result)
  })

  it("returns NULL if context is NULL", {
    metadata <- list(chart_type = "run", centerline = 36)

    result <- build_gemini_prompt(metadata, NULL)

    expect_null(result)
  })

  it("returns NULL if template is NULL", {
    metadata <- list(chart_type = "run", centerline = 36)
    context <- list(data_definition = "Test", target_value = 30)

    stub(build_gemini_prompt, "get_improvement_suggestion_template", function() NULL)

    result <- build_gemini_prompt(metadata, context)

    expect_null(result)
  })

  it("returns NULL if template is empty string", {
    metadata <- list(chart_type = "run", centerline = 36)
    context <- list(data_definition = "Test", target_value = 30)

    stub(build_gemini_prompt, "get_improvement_suggestion_template", function() "")

    result <- build_gemini_prompt(metadata, context)

    expect_null(result)
  })

  it("returns NULL if interpolate_prompt returns NULL", {
    metadata <- list(chart_type = "run", centerline = 36)
    context <- list(data_definition = "Test", target_value = 30)

    stub(build_gemini_prompt, "get_improvement_suggestion_template", function() "template")
    stub(build_gemini_prompt, "interpolate_prompt", function(t, d) NULL)

    result <- build_gemini_prompt(metadata, context)

    expect_null(result)
  })
})

# ============================================================================
# Test Suite 4: generate_improvement_suggestion()
# ============================================================================

describe("generate_improvement_suggestion()", {

  # Helper function to create mock session
  create_mock_session <- function() {
    session <- list(
      userData = new.env(),
      ns = function(x) x
    )
    class(session) <- "ShinySession"
    session
  }

  it("returns character string for valid inputs", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(
      data_definition = "Ventetid til operation",
      chart_title = "Ventetid 2024",
      y_axis_unit = "dage",
      target_value = 30
    )
    session <- create_mock_session()

    # Mock all dependencies
    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run", centerline = 36, signals_detected = 3))
    stub(generate_improvement_suggestion, "generate_ai_cache_key",
         function(m, c) "mock_cache_key")
    stub(generate_improvement_suggestion, "get_cached_ai_response",
         function(k, s) NULL)
    stub(generate_improvement_suggestion, "build_gemini_prompt",
         function(m, c) "Mock prompt text")
    stub(generate_improvement_suggestion, "get_ai_config",
         function() list(model = "gemini-2.0-flash-exp", timeout_seconds = 10))
    stub(generate_improvement_suggestion, "call_gemini_api",
         function(prompt, model, timeout) "AI generated suggestion text")
    stub(generate_improvement_suggestion, "validate_gemini_response",
         function(r, m) "Validated AI text")
    stub(generate_improvement_suggestion, "cache_ai_response",
         function(k, v, s) TRUE)

    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_type(result, "character")
    expect_equal(result, "Validated AI text")
  })

  it("calls extract_spc_metadata() with spc_result", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    mock_extract <- mock(list(chart_type = "run", centerline = 36))
    stub(generate_improvement_suggestion, "extract_spc_metadata", mock_extract)
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) "cached")

    generate_improvement_suggestion(spc_result, context, session)

    expect_called(mock_extract, 1)
    expect_args(mock_extract, 1, spc_result)
  })

  it("calls generate_ai_cache_key() with metadata and context", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    metadata <- list(chart_type = "run", centerline = 36)

    stub(generate_improvement_suggestion, "extract_spc_metadata", function(spc) metadata)
    mock_cache_key <- mock("mock_cache_key")
    stub(generate_improvement_suggestion, "generate_ai_cache_key", mock_cache_key)
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) "cached")

    generate_improvement_suggestion(spc_result, context, session)

    expect_called(mock_cache_key, 1)
    expect_args(mock_cache_key, 1, metadata, context)
  })

  it("calls get_cached_ai_response() with cache_key and session", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key123")
    mock_get_cached <- mock("cached_result")
    stub(generate_improvement_suggestion, "get_cached_ai_response", mock_get_cached)

    generate_improvement_suggestion(spc_result, context, session)

    expect_called(mock_get_cached, 1)
    expect_args(mock_get_cached, 1, "key123", session)
  })

  it("returns cached result if available (cache hit)", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response",
         function(k, s) "Cached suggestion text")

    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_equal(result, "Cached suggestion text")
  })

  it("calls build_gemini_prompt() on cache miss", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    metadata <- list(chart_type = "run", centerline = 36)

    stub(generate_improvement_suggestion, "extract_spc_metadata", function(spc) metadata)
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) NULL)
    mock_build_prompt <- mock("Prompt text")
    stub(generate_improvement_suggestion, "build_gemini_prompt", mock_build_prompt)
    stub(generate_improvement_suggestion, "get_ai_config", function() list(model = "m", timeout_seconds = 10))
    stub(generate_improvement_suggestion, "call_gemini_api", function(prompt, model, timeout) "response")
    stub(generate_improvement_suggestion, "validate_gemini_response", function(r, m) "validated")
    stub(generate_improvement_suggestion, "cache_ai_response", function(k, v, s) TRUE)

    generate_improvement_suggestion(spc_result, context, session)

    expect_called(mock_build_prompt, 1)
    expect_args(mock_build_prompt, 1, metadata, context)
  })

  it("calls call_gemini_api() with prompt on cache miss", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) NULL)
    stub(generate_improvement_suggestion, "build_gemini_prompt", function(m, c) "Full prompt text")
    stub(generate_improvement_suggestion, "get_ai_config",
         function() list(model = "gemini-2.0-flash-exp", timeout_seconds = 10))
    mock_call_api <- mock("API response text")
    stub(generate_improvement_suggestion, "call_gemini_api", mock_call_api)
    stub(generate_improvement_suggestion, "validate_gemini_response", function(r, m) r)
    stub(generate_improvement_suggestion, "cache_ai_response", function(k, v, s) TRUE)

    generate_improvement_suggestion(spc_result, context, session)

    expect_called(mock_call_api, 1)
    # Note: Function called with named args: prompt=, model=, timeout=
    call_args <- mock_args(mock_call_api)[[1]]
    expect_equal(call_args$prompt, "Full prompt text")
    expect_equal(call_args$model, "gemini-2.0-flash-exp")
    expect_equal(call_args$timeout, 10)
  })

  it("calls validate_gemini_response() with API response", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) NULL)
    stub(generate_improvement_suggestion, "build_gemini_prompt", function(m, c) "prompt")
    stub(generate_improvement_suggestion, "get_ai_config", function() list(model = "m", timeout_seconds = 10))
    stub(generate_improvement_suggestion, "call_gemini_api", function(prompt, model, timeout) "Raw API response")
    mock_validate <- mock("Validated response")
    stub(generate_improvement_suggestion, "validate_gemini_response", mock_validate)
    stub(generate_improvement_suggestion, "cache_ai_response", function(k, v, s) TRUE)

    generate_improvement_suggestion(spc_result, context, session, max_chars = 350)

    expect_called(mock_validate, 1)
    # Check arguments
    call_args <- mock_args(mock_validate)[[1]]
    expect_equal(call_args[[1]], "Raw API response")
    expect_equal(call_args[[2]], 350)
  })

  it("calls cache_ai_response() after successful validation", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "cache_key_123")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) NULL)
    stub(generate_improvement_suggestion, "build_gemini_prompt", function(m, c) "prompt")
    stub(generate_improvement_suggestion, "get_ai_config", function() list(model = "m", timeout_seconds = 10))
    stub(generate_improvement_suggestion, "call_gemini_api", function(prompt, model, timeout) "response")
    stub(generate_improvement_suggestion, "validate_gemini_response",
         function(r, m) "Validated text")
    mock_cache <- mock(TRUE)
    stub(generate_improvement_suggestion, "cache_ai_response", mock_cache)

    generate_improvement_suggestion(spc_result, context, session)

    expect_called(mock_cache, 1)
    # Check arguments
    call_args <- mock_args(mock_cache)[[1]]
    expect_equal(call_args[[1]], "cache_key_123")
    expect_equal(call_args[[2]], "Validated text")
    expect_equal(call_args[[3]], session)
  })

  it("returns NULL if spc_result is NULL", {
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    result <- generate_improvement_suggestion(NULL, context, session)

    expect_null(result)
  })

  it("returns NULL if context is NULL", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    session <- create_mock_session()

    result <- generate_improvement_suggestion(spc_result, NULL, session)

    expect_null(result)
  })

  it("returns NULL if session is NULL", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)

    result <- generate_improvement_suggestion(spc_result, context, NULL)

    expect_null(result)
  })

  it("returns NULL if extract_spc_metadata() fails", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata", function(spc) NULL)

    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_null(result)
  })

  it("returns NULL if build_gemini_prompt() fails", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) NULL)
    stub(generate_improvement_suggestion, "build_gemini_prompt", function(m, c) NULL)

    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_null(result)
  })

  it("returns NULL if call_gemini_api() returns NULL", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) NULL)
    stub(generate_improvement_suggestion, "build_gemini_prompt", function(m, c) "prompt")
    stub(generate_improvement_suggestion, "get_ai_config", function() list(model = "m", timeout_seconds = 10))
    stub(generate_improvement_suggestion, "call_gemini_api", function(prompt, model, timeout) NULL)

    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_null(result)
  })

  it("returns NULL if validate_gemini_response() returns NULL", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) NULL)
    stub(generate_improvement_suggestion, "build_gemini_prompt", function(m, c) "prompt")
    stub(generate_improvement_suggestion, "get_ai_config", function() list(model = "m", timeout_seconds = 10))
    stub(generate_improvement_suggestion, "call_gemini_api", function(prompt, model, timeout) "response")
    stub(generate_improvement_suggestion, "validate_gemini_response", function(r, m) NULL)

    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_null(result)
  })

  it("does NOT call build_gemini_prompt when cache hits", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) "Cached")
    mock_build <- mock("Should not be called")
    stub(generate_improvement_suggestion, "build_gemini_prompt", mock_build)

    generate_improvement_suggestion(spc_result, context, session)

    expect_called(mock_build, 0)
  })

  it("does NOT call call_gemini_api when cache hits", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) "Cached")
    mock_api <- mock("Should not be called")
    stub(generate_improvement_suggestion, "call_gemini_api", mock_api)

    generate_improvement_suggestion(spc_result, context, session)

    expect_called(mock_api, 0)
  })

  it("does NOT call cache_ai_response when cache hits", {
    spc_result <- readRDS("fixtures/sample_spc_result.rds")
    context <- list(data_definition = "Test", target_value = 30)
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "extract_spc_metadata",
         function(spc) list(chart_type = "run"))
    stub(generate_improvement_suggestion, "generate_ai_cache_key", function(m, c) "key")
    stub(generate_improvement_suggestion, "get_cached_ai_response", function(k, s) "Cached")
    mock_cache <- mock(TRUE)
    stub(generate_improvement_suggestion, "cache_ai_response", mock_cache)

    generate_improvement_suggestion(spc_result, context, session)

    expect_called(mock_cache, 0)
  })
})
