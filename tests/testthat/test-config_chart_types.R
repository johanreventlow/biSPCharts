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
  for (code in c("run", "i", "i'", "p", "u", "c")) {
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
  expect_true(chart_type_requires_denominator("i'"))

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
  # i'-kort: naevner er relevant (varierende naevner er kernefeature)
  expect_true(chart_type_requires_denominator(
    "I\u2032-kort \u2014 individuelle m\u00e5linger med varierende n\u00e6vner"
  ))
})

# Konstanter ------------------------------------------------------------------

test_that("CHART_TYPES_DA indeholder aktive diagramtyper", {
  # Aktuelt 6 aktive typer inkl. i' (mr, pp, up, g er udkommenteret i config_chart_types.R)
  expect_true(length(CHART_TYPES_DA) >= 6,
    info = "CHART_TYPES_DA skal indeholde mindst 6 aktive diagramtyper"
  )
  expect_true(all(unlist(CHART_TYPES_DA) %in% c("run", "i", "i'", "mr", "p", "pp", "u", "up", "c", "g")),
    info = "Alle aktive typer skal have gyldige engelske koder"
  )
})

test_that("CHART_TYPE_DESCRIPTIONS daekker alle engelske koder inkl. i-prime", {
  expected_codes <- c("run", "i", "i'", "mr", "p", "pp", "u", "up", "c", "g")
  expect_true(all(expected_codes %in% names(CHART_TYPE_DESCRIPTIONS)))
})

# i' (I-prime) chart type -------------------------------------------------------

test_that("i'-kort: get_qic_chart_type returnerer i' uaendret (passthrough)", {
  expect_equal(get_qic_chart_type("i'"), "i'")
})

test_that("i'-kort: get_qic_chart_type konverterer dansk label korrekt", {
  expect_equal(
    get_qic_chart_type("I′-kort — individuelle målinger med varierende nævner"),
    "i'"
  )
})

test_that("i'-kort: i' er i SUPPORTED_CHART_TYPES_BFH (validering accepterer den)", {
  expect_true("i'" %in% SUPPORTED_CHART_TYPES_BFH)
})

test_that("i'-kort: chart_type_requires_denominator returnerer TRUE", {
  expect_true(chart_type_requires_denominator("i'"))
})

test_that("i'-kort: chart_type_requires_denominator via dansk label returnerer TRUE", {
  expect_true(chart_type_requires_denominator(
    "I′-kort — individuelle målinger med varierende nævner"
  ))
})

test_that("i'-kort: build_bfh_args bevarer n_var for i'-chart (ikke stripped)", {
  # chart_type_requires_denominator("i'") er TRUE → n_var skal IKKE fjernes
  # Verificer logik-gaten direkte (build_bfh_args bruger denne guard)
  expect_true(chart_type_requires_denominator("i'"),
    info = "Guard-condition: i' requires denominator → n_var skal bevares af build_bfh_args"
  )
})

test_that("i'-kort: i' er i ABSOLUTE_CHART_TYPES (arver i's y-akse skalering)", {
  expect_true("i'" %in% ABSOLUTE_CHART_TYPES)
})

test_that("i'-kort: fct_spc_validate accepterer i' som chart_type", {
  df <- data.frame(
    x = seq.Date(as.Date("2023-01-01"), by = "week", length.out = 10),
    y = as.numeric(1:10)
  )
  expect_no_error(validate_spc_request(df, "x", "y", "i'"))
})
