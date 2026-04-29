# test-gemini-payload-stripping.R
# Tests: CPR-gate i generate_improvement_suggestion (Phase 4)

# Hjælper: minimal spc_result med metadata
make_test_spc_result <- function() {
  list(
    metadata = list(
      chart_type = "run",
      n_points = 24L,
      signals_detected = 0L,
      anhoej_rules = list(
        longest_run = 5L,
        n_crossings = 12L,
        n_crossings_min = 10L
      )
    ),
    qic_data = data.frame(
      x = seq.Date(as.Date("2026-01-01"), by = "month", length.out = 24),
      cl = rep(10, 24),
      stringsAsFactors = FALSE
    )
  )
}

test_that("generate_improvement_suggestion returnerer NULL ved CPR-mønster med bindestreg", {
  skip_if(
    !exists("generate_improvement_suggestion",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "generate_improvement_suggestion ikke tilgængelig"
  )
  skip_if_not_installed("shiny")

  context_with_cpr <- list(
    data_definition = "Ventetid for patient 010188-1234 i dage",
    chart_title = "Test",
    target_value = NULL
  )

  # NULL-session udløser SESSION_NULL-check, men CPR-check er FØR den check.
  # Vi sender valid mock-session — CPR-gate returnerer NULL før BFHllm-kald.
  result <- biSPCharts:::generate_improvement_suggestion(
    spc_result = make_test_spc_result(),
    context = context_with_cpr,
    session = list(token = "tok", ns = function(id) id)
  )

  expect_null(result, "CPR-mønster skal blokere AI-kald og returnere NULL")
})

test_that("generate_improvement_suggestion returnerer NULL ved CPR-mønster uden bindestreg", {
  skip_if(
    !exists("generate_improvement_suggestion",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "generate_improvement_suggestion ikke tilgængelig"
  )
  skip_if_not_installed("shiny")

  context_with_cpr <- list(
    data_definition = "Indikator for patient 0101881234",
    chart_title = "Test",
    target_value = NULL
  )

  result <- biSPCharts:::generate_improvement_suggestion(
    spc_result = make_test_spc_result(),
    context = context_with_cpr,
    session = list(token = "tok", ns = function(id) id)
  )

  expect_null(result, "CPR uden bindestreg skal også blokeres")
})

test_that("CPR-mønster i data_definition detekteres korrekt med grepl", {
  # Unit-test af selve detection-logikken isoleret fra Shiny-session
  cpr_patterns <- c(
    "patient 010188-1234",
    "cpr: 0101881234",
    "010188-1234 er ekskluderet"
  )
  for (text in cpr_patterns) {
    expect_true(
      grepl("\\d{6}-?\\d{4}", text, perl = TRUE),
      info = paste("Skal detektere CPR i:", text)
    )
  }

  safe_texts <- c(
    "Ventetid til operation i dage",
    "Antal infektioner pr. måned",
    "Data fra afdeling 1234"
  )
  for (text in safe_texts) {
    expect_false(
      grepl("\\d{6}-?\\d{4}", text, perl = TRUE),
      info = paste("Skal IKKE detektere CPR i:", text)
    )
  }
})

test_that("CPR-gate blokerer kald ved CPR i data_definition (direkte logik)", {
  # Test CPR-gate logikken direkte uden Shiny session context
  data_def_with_cpr <- "Ventetid for patient 010188-1234 i dage"
  data_def_safe <- "Ventetid til operation i dage"
  data_def_empty <- ""

  # CPR-pattern matcher
  expect_true(grepl("\\d{6}-?\\d{4}", data_def_with_cpr, perl = TRUE))
  # Safe tekst matcher ikke
  expect_false(grepl("\\d{6}-?\\d{4}", data_def_safe, perl = TRUE))
  # Tom tekst: nchar()==0 guard forhindrer check
  expect_false(nchar(data_def_empty) > 0 &&
    grepl("\\d{6}-?\\d{4}", data_def_empty, perl = TRUE))
})
