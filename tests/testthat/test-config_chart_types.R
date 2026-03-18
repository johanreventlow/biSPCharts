# Tests for config_chart_types.R

# get_qic_chart_type() --------------------------------------------------------

test_that("get_qic_chart_type konverterer danske labels korrekt", {
  expect_equal(get_qic_chart_type("Seriediagram m SPC (Run Chart)"), "run")
  expect_equal(get_qic_chart_type("I-kort (Individuelle værdier)"), "i")
  expect_equal(get_qic_chart_type("MR-kort (Moving Range)"), "mr")
  expect_equal(get_qic_chart_type("P-kort (Andele)"), "p")
  expect_equal(get_qic_chart_type("P'-kort (Andele, standardiseret)"), "pp")
  expect_equal(get_qic_chart_type("U-kort (Rater)"), "u")
  expect_equal(get_qic_chart_type("U'-kort (Rater, standardiseret)"), "up")
  expect_equal(get_qic_chart_type("C-kort (Tællinger)"), "c")
  expect_equal(get_qic_chart_type("G-kort (Tid mellem hændelser)"), "g")
})

test_that("get_qic_chart_type returnerer engelske koder uændret", {
  for (code in c("run", "i", "mr", "p", "pp", "u", "up", "c", "g")) {
    expect_equal(get_qic_chart_type(code), code)
  }
})

test_that("get_qic_chart_type håndterer edge cases med fallback til run", {
  expect_equal(get_qic_chart_type(NULL), "run")
  expect_equal(get_qic_chart_type(""), "run")
  expect_equal(get_qic_chart_type("ukendt type"), "run")
})

# chart_type_requires_denominator() -------------------------------------------

test_that("chart_type_requires_denominator identificerer korrekte typer", {
  # Typer der kræver nævner
  expect_true(chart_type_requires_denominator("run"))
  expect_true(chart_type_requires_denominator("p"))
  expect_true(chart_type_requires_denominator("pp"))
  expect_true(chart_type_requires_denominator("u"))
  expect_true(chart_type_requires_denominator("up"))

  # Typer der IKKE kræver nævner
  expect_false(chart_type_requires_denominator("i"))
  expect_false(chart_type_requires_denominator("mr"))
  expect_false(chart_type_requires_denominator("c"))
  expect_false(chart_type_requires_denominator("g"))
})

test_that("chart_type_requires_denominator accepterer danske labels", {
  expect_true(chart_type_requires_denominator("P-kort (Andele)"))
  expect_false(chart_type_requires_denominator("I-kort (Individuelle værdier)"))
})

# Konstanter ------------------------------------------------------------------

test_that("CHART_TYPES_DA indeholder alle 9 diagramtyper", {
  expect_length(CHART_TYPES_DA, 9)
  expect_true(all(unlist(CHART_TYPES_DA) %in% c("run", "i", "mr", "p", "pp", "u", "up", "c", "g")))
})

test_that("CHART_TYPE_DESCRIPTIONS dækker alle engelske koder", {
  expected_codes <- c("run", "i", "mr", "p", "pp", "u", "up", "c", "g")
  expect_true(all(expected_codes %in% names(CHART_TYPE_DESCRIPTIONS)))
})
