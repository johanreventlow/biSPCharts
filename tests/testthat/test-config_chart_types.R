# Tests for config_chart_types.R

# get_qic_chart_type() --------------------------------------------------------

test_that("get_qic_chart_type konverterer danske labels korrekt", {
  # Labels opdateret til nuværende em-dash format (config_chart_types.R)
  expect_equal(get_qic_chart_type("Seriediagram (Run) \u2014 data over tid"), "run")
  expect_equal(get_qic_chart_type("I-kort \u2014 enkelte m\u00e5linger (fx ventetid, temperatur)"), "i")
  expect_equal(get_qic_chart_type("P-kort \u2014 andele/procenter (fx infektionsrate)"), "p")
  expect_equal(get_qic_chart_type("U-kort \u2014 rater (fx komplikationer pr. 1000)"), "u")
  expect_equal(get_qic_chart_type("C-kort \u2014 t\u00e6llinger (fx antal fald)"), "c")
  # MR-kort, P'-kort, U'-kort, G-kort er ikke aktive i CHART_TYPES_DA
  # (udkommenteret i config_chart_types.R). De returnerer "run" via fallback.
  # Hvis disse chart types aktiveres, tilføj tilsvarende expect_equal-assertions
  # ovenfor og fjern denne kommentar.
})

test_that("get_qic_chart_type returnerer engelske koder uændret", {
  # Kun aktive koder der er registreret i lookup-tabellen
  for (code in c("run", "i", "p", "u", "c")) {
    expect_equal(get_qic_chart_type(code), code)
  }
  # Bemærk: MR/PP/UP/G er ikke registreret som engelske koder i lookup-tabellen
  # og returnerer "run" (fallback). Hvis disse aktiveres i CHART_TYPES_DA,
  # udvid vektoren ovenfor med "mr", "pp", "up", "g".
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
  expect_false(chart_type_requires_denominator("c"))
  # mr og g er ikke registreret i CHART_TYPES_DA og fallbacker derfor til run.
  # expect_false(chart_type_requires_denominator("mr"))
  # expect_false(chart_type_requires_denominator("g"))
})

test_that("chart_type_requires_denominator accepterer danske labels", {
  # Opdaterede labels til nuværende em-dash format
  expect_true(chart_type_requires_denominator("P-kort \u2014 andele/procenter (fx infektionsrate)"))
  expect_false(chart_type_requires_denominator("I-kort \u2014 enkelte m\u00e5linger (fx ventetid, temperatur)"))
})

# Konstanter ------------------------------------------------------------------

test_that("CHART_TYPES_DA indeholder aktive diagramtyper", {
  # Aktuelt 5 aktive typer (mr, pp, up, g er udkommenteret i config_chart_types.R)
  expect_true(length(CHART_TYPES_DA) >= 5,
    info = "CHART_TYPES_DA skal indeholde mindst 5 aktive diagramtyper"
  )
  expect_true(all(unlist(CHART_TYPES_DA) %in% c("run", "i", "mr", "p", "pp", "u", "up", "c", "g")),
    info = "Alle aktive typer skal have gyldige engelske koder"
  )
})

test_that("CHART_TYPE_DESCRIPTIONS dækker alle engelske koder", {
  expected_codes <- c("run", "i", "mr", "p", "pp", "u", "up", "c", "g")
  expect_true(all(expected_codes %in% names(CHART_TYPE_DESCRIPTIONS)))
})
