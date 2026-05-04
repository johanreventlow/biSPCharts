library(testthat)

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# ==============================================================================
# TEST: PDF eksport-footnote (#485)
# ==============================================================================
# Footnote-feltet (input$export_footnote) sendes til BFHcharts Typst-template
# som metadata$footer_content. Tester:
#   - build_export_analysis_metadata propagerer footnote
#   - escape_typst_metadata anvendes paa user-input
#   - validator hardener length-cap
#   - LLM-context truncation dækker footnote
# ==============================================================================

# SETUP -------------------------------------------------------------------------

if (!exists("EXPORT_FOOTNOTE_MAX_LENGTH")) {
  EXPORT_FOOTNOTE_MAX_LENGTH <- 500L
}

if (!exists("EXPORT_DESCRIPTION_MAX_LENGTH")) {
  EXPORT_DESCRIPTION_MAX_LENGTH <- 2000
}

make_mock_bfh_qic_result <- function(centerline = 50,
                                     y_axis_unit = "count") {
  result <- list(
    config = list(y_axis_unit = y_axis_unit),
    summary = data.frame(centerlinje = centerline),
    qic_data = data.frame(cl = rep(centerline, 3))
  )
  class(result) <- "bfh_qic_result"
  result
}

# BUILD_EXPORT_ANALYSIS_METADATA ------------------------------------------------

test_that("build_export_analysis_metadata propagerer footnote til output", {
  if (!exists("build_export_analysis_metadata", mode = "function")) {
    skip("build_export_analysis_metadata ikke tilgaengelig — skip i R CMD check miljo")
  }

  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_mock_bfh_qic_result(),
    footnote = "Datakilde: KvalDB udtraek 2026-04-29"
  )

  expect_equal(metadata$footnote, "Datakilde: KvalDB udtraek 2026-04-29")
})

test_that("build_export_analysis_metadata defaulter footnote til tom streng", {
  if (!exists("build_export_analysis_metadata", mode = "function")) {
    skip("build_export_analysis_metadata ikke tilgaengelig — skip i R CMD check miljo")
  }

  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_mock_bfh_qic_result()
  )

  expect_equal(metadata$footnote, "")
})

test_that("build_export_analysis_metadata haandterer NULL footnote", {
  if (!exists("build_export_analysis_metadata", mode = "function")) {
    skip("build_export_analysis_metadata ikke tilgaengelig — skip i R CMD check miljo")
  }

  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_mock_bfh_qic_result(),
    footnote = NULL
  )

  expect_equal(metadata$footnote, "")
})

# ESCAPE_TYPST_METADATA ---------------------------------------------------------

test_that("escape_typst_metadata escapes footnote markup-tegn", {
  if (!exists("escape_typst_metadata", mode = "function")) {
    skip("escape_typst_metadata ikke tilgaengelig — skip i R CMD check miljo")
  }

  raw <- "Datakilde: *intern* rapport @afd"
  escaped <- escape_typst_metadata(raw)

  expect_true(grepl("\\\\\\*intern\\\\\\*", escaped))
  expect_true(grepl("\\\\@afd", escaped))
})

# VALIDATOR ---------------------------------------------------------------------

test_that("validate_export_inputs accepterer footnote ved EXPORT_FOOTNOTE_MAX_LENGTH", {
  if (!exists("validate_export_inputs", mode = "function")) {
    skip("validate_export_inputs ikke tilgaengelig — skip i R CMD check miljo")
  }

  exact <- paste(rep("A", EXPORT_FOOTNOTE_MAX_LENGTH), collapse = "")
  expect_true(validate_export_inputs(format = "pdf", footnote = exact))
})

test_that("validate_export_inputs rejecter footnote over EXPORT_FOOTNOTE_MAX_LENGTH", {
  if (!exists("validate_export_inputs", mode = "function")) {
    skip("validate_export_inputs ikke tilgaengelig — skip i R CMD check miljo")
  }

  long <- paste(rep("A", EXPORT_FOOTNOTE_MAX_LENGTH + 1L), collapse = "")
  expect_error(
    validate_export_inputs(format = "pdf", footnote = long),
    "Fodnote"
  )
})

# LLM-CONTEXT TRUNCATION --------------------------------------------------------

test_that("truncate_llm_context_fields truncerer footnote ved over-cap (#489)", {
  if (!exists("truncate_llm_context_fields", mode = "function")) {
    skip("truncate_llm_context_fields ikke tilgaengelig — skip i R CMD check miljo")
  }

  long_footnote <- paste(rep("A", EXPORT_DESCRIPTION_MAX_LENGTH + 100L), collapse = "")
  context <- list(
    footnote = long_footnote,
    chart_title = "Test"
  )
  result <- truncate_llm_context_fields(context, max_length = EXPORT_DESCRIPTION_MAX_LENGTH)

  expect_equal(nchar(result$footnote), EXPORT_DESCRIPTION_MAX_LENGTH)
})

test_that("truncate_llm_context_fields bevarer kort footnote uaendret", {
  if (!exists("truncate_llm_context_fields", mode = "function")) {
    skip("truncate_llm_context_fields ikke tilgaengelig — skip i R CMD check miljo")
  }

  short_footnote <- "Datakilde: KvalDB"
  context <- list(footnote = short_footnote)
  result <- truncate_llm_context_fields(context, max_length = EXPORT_DESCRIPTION_MAX_LENGTH)

  expect_equal(result$footnote, short_footnote)
})
