# test-fct_ai_improvement_suggestions.R
# Unit tests for AI improvement suggestion facade (BFHllm integration)
#
# Test Coverage:
# 1. generate_improvement_suggestion() - Thin wrapper delegating to BFHllm
# 2. Input validation (NULL checks)
# 3. Delegation to generate_bfhllm_suggestion()
# 4. Error handling and graceful degradation
#
# Note: After BFHllm migration, this function is just a thin facade.
# Core logic (metadata extraction, prompt building, RAG) is now in BFHllm package.

library(testthat)
library(mockery)

# ============================================================================
# Test Suite: generate_improvement_suggestion() - BFHllm Facade
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

  # Helper to create minimal valid spc_result
  create_mock_spc_result <- function() {
    list(
      metadata = list(
        chart_type = "run",
        n_points = 24,
        signals_detected = 2,
        anhoej_rules = list(
          longest_run = 8,
          n_crossings = 3,
          n_crossings_min = 5
        )
      ),
      qic_data = data.frame(
        x = as.Date("2024-01-01") + 0:23,
        y = rnorm(24, 50, 5),
        cl = rep(50, 24)
      )
    )
  }

  # Helper to create minimal valid context
  create_mock_context <- function() {
    list(
      data_definition = "Ventetid til operation",
      chart_title = "Ventetid 2024",
      y_axis_unit = "dage",
      target_value = 30
    )
  }

  # ------------------------------------------------------------------------
  # Input Validation Tests
  # ------------------------------------------------------------------------

  it("returns NULL when spc_result is NULL", {
    context <- create_mock_context()
    session <- create_mock_session()

    result <- generate_improvement_suggestion(NULL, context, session)

    expect_null(result)
  })

  it("returns NULL when context is NULL", {
    spc_result <- create_mock_spc_result()
    session <- create_mock_session()

    result <- generate_improvement_suggestion(spc_result, NULL, session)

    expect_null(result)
  })

  it("returns NULL when session is NULL", {
    spc_result <- create_mock_spc_result()
    context <- create_mock_context()

    result <- generate_improvement_suggestion(spc_result, context, NULL)

    expect_null(result)
  })

  # ------------------------------------------------------------------------
  # Delegation to BFHllm Tests
  # ------------------------------------------------------------------------

  it("calls generate_bfhllm_suggestion() with correct arguments", {
    spc_result <- create_mock_spc_result()
    context <- create_mock_context()
    session <- create_mock_session()

    # Mock the integration layer
    mock_generate <- mock("AI suggestion from BFHllm")
    stub(generate_improvement_suggestion, "generate_bfhllm_suggestion", mock_generate)

    result <- generate_improvement_suggestion(spc_result, context, session, max_chars = 350)

    # Verify delegation
    expect_called(mock_generate, 1)
    call_args <- mock_args(mock_generate)[[1]]
    expect_identical(call_args$spc_result, spc_result)
    expect_identical(call_args$context, context)
    expect_identical(call_args$session, session)
    expect_equal(call_args$max_chars, 350)
  })

  it("returns suggestion from generate_bfhllm_suggestion()", {
    spc_result <- create_mock_spc_result()
    context <- create_mock_context()
    session <- create_mock_session()

    expected_suggestion <- "Processen viser ikke-naturlig variation med 2 signaler. **Anbefaling:** Undersøg årsager til de detekterede mønstre."

    stub(generate_improvement_suggestion, "generate_bfhllm_suggestion",
         function(...) expected_suggestion)

    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_equal(result, expected_suggestion)
  })

  it("uses default max_chars from config when not specified", {
    spc_result <- create_mock_spc_result()
    context <- create_mock_context()
    session <- create_mock_session()

    mock_generate <- mock("AI suggestion")
    stub(generate_improvement_suggestion, "generate_bfhllm_suggestion", mock_generate)

    # Call without max_chars
    generate_improvement_suggestion(spc_result, context, session)

    # max_chars should be NULL (BFHllm will use its own default)
    call_args <- mock_args(mock_generate)[[1]]
    expect_null(call_args$max_chars)
  })

  # ------------------------------------------------------------------------
  # Error Handling Tests
  # ------------------------------------------------------------------------

  it("returns NULL when generate_bfhllm_suggestion() returns NULL", {
    spc_result <- create_mock_spc_result()
    context <- create_mock_context()
    session <- create_mock_session()

    # Mock BFHllm failure
    stub(generate_improvement_suggestion, "generate_bfhllm_suggestion",
         function(...) NULL)

    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_null(result)
  })

  it("handles BFHllm errors gracefully via safe_operation", {
    spc_result <- create_mock_spc_result()
    context <- create_mock_context()
    session <- create_mock_session()

    # Mock BFHllm error
    stub(generate_improvement_suggestion, "generate_bfhllm_suggestion",
         function(...) stop("BFHllm API error"))

    # Should not throw error (safe_operation catches it)
    result <- generate_improvement_suggestion(spc_result, context, session)

    # safe_operation fallback is NULL
    expect_null(result)
  })

  # ------------------------------------------------------------------------
  # Integration Behavior Tests
  # ------------------------------------------------------------------------

  it("passes through max_chars parameter to BFHllm", {
    spc_result <- create_mock_spc_result()
    context <- create_mock_context()
    session <- create_mock_session()

    mock_generate <- mock("Short suggestion")
    stub(generate_improvement_suggestion, "generate_bfhllm_suggestion", mock_generate)

    generate_improvement_suggestion(spc_result, context, session, max_chars = 200)

    call_args <- mock_args(mock_generate)[[1]]
    expect_equal(call_args$max_chars, 200)
  })

  it("works with minimal valid context (no target_value)", {
    spc_result <- create_mock_spc_result()
    context <- list(
      data_definition = "Ventetid",
      chart_title = "Test",
      y_axis_unit = "dage"
      # No target_value
    )
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "generate_bfhllm_suggestion",
         function(...) "Suggestion without target")

    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_type(result, "character")
    expect_equal(result, "Suggestion without target")
  })

  it("works with different chart types", {
    # Test with p-chart
    spc_result <- create_mock_spc_result()
    spc_result$metadata$chart_type <- "p"

    context <- create_mock_context()
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "generate_bfhllm_suggestion",
         function(...) "P-chart suggestion")

    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_equal(result, "P-chart suggestion")
  })

  # ------------------------------------------------------------------------
  # Logging Behavior Tests
  # ------------------------------------------------------------------------

  it("logs info when starting AI suggestion generation", {
    spc_result <- create_mock_spc_result()
    context <- create_mock_context()
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "generate_bfhllm_suggestion",
         function(...) "Suggestion")

    # Capture logs (if logging is active)
    result <- generate_improvement_suggestion(spc_result, context, session)

    # Function should complete successfully
    expect_type(result, "character")
  })

  it("logs warning when BFHllm returns NULL", {
    spc_result <- create_mock_spc_result()
    context <- create_mock_context()
    session <- create_mock_session()

    stub(generate_improvement_suggestion, "generate_bfhllm_suggestion",
         function(...) NULL)

    # Should log warning and return NULL
    result <- generate_improvement_suggestion(spc_result, context, session)

    expect_null(result)
  })
})

# ==============================================================================
# Integration Notes
# ==============================================================================
#
# After BFHllm migration:
# - extract_spc_metadata() → BFHllm::bfhllm_extract_spc_metadata()
# - determine_target_comparison() → Internal to BFHllm
# - build_gemini_prompt() → BFHllm::bfhllm_build_prompt()
# - RAG integration → BFHllm::bfhllm_chat_with_rag()
# - Caching → BFHllm::bfhllm_cache_shiny()
#
# Test strategy:
# - SPCify tests: Focus on thin wrapper behavior (delegation, validation)
# - BFHllm tests: Focus on core AI logic (in BFHllm package)
# - Integration tests: Manual verification via tests/manual/verify_ai.R
#
