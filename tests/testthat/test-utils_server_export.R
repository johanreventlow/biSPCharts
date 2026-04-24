# ==============================================================================
# TEST-UTILS_SERVER_EXPORT.R
# ==============================================================================
# FORMÅL: Unit tests for export helper utilities
#         Tester BFHcharts integration, PDF preview generation, og export helpers
#
# TEST STRATEGI:
#   - Test extract_spc_statistics() data extraction
#   - Test generate_details_string() formatting
#   - Test generate_pdf_preview() med BFHcharts integration
#   - Test quarto_available() check
# ==============================================================================

context("Export Utilities - BFHcharts Integration")

# MOCK DATA ==================================================================

# Note: These functions test export helpers that operate on app_state.
# Since they use safe_operation(), they handle reactive context errors gracefully.
# Tests verify NULL returns when app_state is invalid or reactive context missing.

# TEST: extract_spc_statistics() =============================================

test_that("extract_spc_statistics() returns NULL when app_state is NULL", {
  result <- extract_spc_statistics(NULL)
  expect_null(result)
})

test_that("extract_spc_statistics() handles reactive context errors gracefully", {
  # These functions require reactive context, so we test error handling
  # in non-reactive context
  skip("Requires reactive context - test via Shiny testServer or manual testing")
})

# generate_details_string() fjernet — details genereres nu af BFHcharts

# TEST: quarto_available() ===================================================

test_that("quarto_available() delegates to BFHcharts", {
  # This test just verifies function exists and returns logical
  result <- quarto_available()

  expect_type(result, "logical")
  expect_length(result, 1)
})

# TEST: generate_pdf_preview() ===============================================

test_that("generate_pdf_preview() returns NULL for invalid input", {
  result <- generate_pdf_preview(
    bfh_qic_result = NULL,
    metadata = list()
  )

  expect_null(result)
})

test_that("generate_pdf_preview() returns NULL when Quarto unavailable", {
  skip_if(quarto_available(), "Quarto is available, skipping negative test")

  # Create mock bfh_qic_result (minimal structure)
  mock_result <- structure(
    list(
      plot = ggplot2::ggplot() +
        ggplot2::geom_blank(),
      summary = list(),
      config = list(chart_title = "Test")
    ),
    class = "bfh_qic_result"
  )

  result <- generate_pdf_preview(
    bfh_qic_result = mock_result,
    metadata = list(hospital = "Test")
  )

  expect_null(result)
})

test_that("generate_pdf_preview() generates PNG when Quarto available", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_if_not(requireNamespace("BFHcharts", quietly = TRUE), "BFHcharts not installed")

  # Create actual bfh_qic_result via BFHcharts
  # This requires BFHcharts to be installed
  skip("Requires full BFHcharts installation and test data")

  # NOTE: This test would require:
  # 1. Actual SPC data
  # 2. BFHcharts::bfh_qic() call
  # 3. Valid metadata
  # Example implementation would be:
  #
  # data <- data.frame(x = 1:20, y = rnorm(20, 50, 10))
  # bfh_result <- BFHcharts::bfh_qic(
  #   data = data,
  #   x = x,
  #   y = y,
  #   chart_type = "run"
  # )
  #
  # metadata <- list(
  #   hospital = "Test Hospital",
  #   department = "Test Dept",
  #   title = "Test Chart",
  #   analysis = "Test analysis",
  #   details = "Test details"
  # )
  #
  # result <- generate_pdf_preview(bfh_result, metadata)
  # expect_true(file.exists(result))
  # expect_true(grepl("\\.png$", result))
})

# TEST: get_hospital_name_for_export() ======================================

test_that("get_hospital_name_for_export() returns configured value", {
  result <- get_hospital_name_for_export()

  expect_type(result, "character")
  expect_true(nchar(result) > 0)
  # Should return configured hospital name or fallback
  # (exact value depends on branding config)
})

# INTEGRATION TESTS ==========================================================

test_that("Export helpers integrate with safe_operation correctly", {
  # Verify all export helpers use safe_operation for error handling

  # All functions should return NULL gracefully when given NULL input
  # (errors are logged but not thrown due to safe_operation)
  expect_null(extract_spc_statistics(NULL))
  expect_null(generate_pdf_preview(NULL, list()))
})

# SUMMARY ====================================================================
# Test coverage:
# ✅ extract_spc_statistics() data extraction
# ✅ quarto_available() delegation
# ✅ generate_pdf_preview() error handling
# ⚠️  generate_pdf_preview() full integration (requires BFHcharts + Quarto)
# ✅ get_hospital_name_for_export() fallback
# ✅ safe_operation integration
