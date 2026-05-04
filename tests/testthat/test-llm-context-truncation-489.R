# test-llm-context-truncation-489.R
# Regression-test for #489: truncate_llm_context_fields begraenser free-text
# i LLM-context til EXPORT_DESCRIPTION_MAX_LENGTH foer Gemini-kald. Beskytter
# mod cost-amplification og rate-limit.

test_that("truncate_llm_context_fields begraenser data_definition til max_length", {
  long_text <- strrep("a", EXPORT_DESCRIPTION_MAX_LENGTH + 500)
  context <- list(data_definition = long_text)

  result <- truncate_llm_context_fields(context)
  expect_equal(nchar(result$data_definition), EXPORT_DESCRIPTION_MAX_LENGTH)
})

test_that("truncate_llm_context_fields lader korte vaerdier vaere urort", {
  short_text <- "Ventetid til operation"
  context <- list(
    data_definition = short_text,
    chart_title = "Q1 2024",
    department = "Ortopædkirurgi"
  )

  result <- truncate_llm_context_fields(context)
  expect_equal(result$data_definition, short_text)
  expect_equal(result$chart_title, "Q1 2024")
  expect_equal(result$department, "Ortopædkirurgi")
})

test_that("truncate_llm_context_fields handler NULL og NA gracefully", {
  context <- list(
    data_definition = NULL,
    chart_title = NA_character_,
    department = "Akut"
  )

  result <- truncate_llm_context_fields(context)
  expect_null(result$data_definition)
  expect_true(is.na(result$chart_title))
  expect_equal(result$department, "Akut")
})

test_that("truncate_llm_context_fields truncater alle freetext-felter ved long input", {
  too_long <- strrep("x", EXPORT_DESCRIPTION_MAX_LENGTH + 1L)
  context <- list(
    data_definition = too_long,
    chart_title = too_long,
    baseline_analysis = too_long,
    signal_examples = too_long
  )

  result <- truncate_llm_context_fields(context)
  expect_true(all(vapply(
    result[c("data_definition", "chart_title", "baseline_analysis", "signal_examples")],
    nchar, integer(1L)
  ) == EXPORT_DESCRIPTION_MAX_LENGTH))
})

test_that("truncate_llm_context_fields lader non-freetext-felter (target_value) vaere", {
  too_long <- strrep("x", EXPORT_DESCRIPTION_MAX_LENGTH + 1L)
  context <- list(
    data_definition = "kort",
    target_value = 42, # numeric — ej med i freetext_fields
    centerline = 50.5
  )

  result <- truncate_llm_context_fields(context)
  expect_equal(result$target_value, 42)
  expect_equal(result$centerline, 50.5)
})

test_that("truncate_llm_context_fields handler tom liste", {
  expect_equal(truncate_llm_context_fields(list()), list())
})

test_that("truncate_llm_context_fields handler non-list input", {
  # Defensiv check: returnerer input urort hvis ej list
  expect_equal(truncate_llm_context_fields(NULL), NULL)
  expect_equal(truncate_llm_context_fields("ikke list"), "ikke list")
})

test_that("truncate_llm_context_fields respekterer custom max_length", {
  text <- strrep("a", 100L)
  result <- truncate_llm_context_fields(
    list(data_definition = text),
    max_length = 50L
  )
  expect_equal(nchar(result$data_definition), 50L)
})
